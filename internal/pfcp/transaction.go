package pfcp

import (
	"fmt"
	"net"
	"time"

	"github.com/pkg/errors"
	"github.com/sirupsen/logrus"
	"github.com/wmnsk/go-pfcp/message"

	"github.com/free5gc/go-upf/internal/logger"
)

type TxTransaction struct {
	server         *PfcpServer
	raddr          net.Addr
	seq            uint32
	id             string
	retransTimeout time.Duration
	maxRetrans     uint8
	req            message.Message
	msgBuf         []byte
	timer          *time.Timer
	retransCount   uint8
	log            *logrus.Entry
}

type RxTransaction struct {
	server  *PfcpServer
	raddr   net.Addr // 远程地址
	seq     uint32
	id      string
	timeout time.Duration
	msgBuf  []byte
	timer   *time.Timer
	log     *logrus.Entry
}

func NewTxTransaction(
	server *PfcpServer,
	raddr net.Addr,
	seq uint32,
) *TxTransaction {
	return &TxTransaction{
		server:         server,
		raddr:          raddr,
		seq:            seq,
		id:             fmt.Sprintf("%s-%d", raddr, seq),
		retransTimeout: server.cfg.Pfcp.RetransTimeout,
		maxRetrans:     server.cfg.Pfcp.MaxRetrans,
		log:            server.log.WithField(logger.FieldTransction, fmt.Sprintf("TxTr:%s(%d)", raddr, seq)),
	}
}

func (tx *TxTransaction) send(req message.Message) error {
	tx.log.Debugf("send req")

	setReqSeq(req, tx.seq)
	b := make([]byte, req.MarshalLen()) // 生成发送request的信息
	err := req.MarshalTo(b)
	if err != nil {
		return err
	}

	// Start tx retransmission timer
	tx.req = req
	tx.msgBuf = b
	tx.timer = tx.startTimer()

	_, err = tx.server.conn.WriteTo(b, tx.raddr) // 向目标发送request信息
	if err != nil {
		return err
	}

	return nil
}

// 接收rsp后，停止tx事务计时器，同时删除 tx字典中的该事物
func (tx *TxTransaction) recv(rsp message.Message) message.Message {
	tx.log.Debugf("recv rsp, delete txtr")

	// Stop tx retransmission timer
	tx.timer.Stop()
	tx.timer = nil

	delete(tx.server.txTrans, tx.id)
	return tx.req
}

func (tx *TxTransaction) handleTimeout() {
	if tx.retransCount < tx.maxRetrans {
		// Start tx retransmission timer
		tx.retransCount++
		tx.log.Debugf("timeout, retransCount(%d)", tx.retransCount)
		_, err := tx.server.conn.WriteTo(tx.msgBuf, tx.raddr)
		if err != nil {
			tx.log.Errorf("retransmit[%d] error: %v", tx.retransCount, err)
		}
		tx.timer = tx.startTimer()
	} else {
		tx.log.Debugf("max retransmission reached - delete txtr")
		delete(tx.server.txTrans, tx.id)
		err := tx.server.txtoDispacher(tx.req, tx.raddr)
		if err != nil {
			tx.log.Errorf("txtoDispacher: %v", err)
		}
	}
}

func (tx *TxTransaction) startTimer() *time.Timer {
	tx.log.Debugf("start timer(%s)", tx.retransTimeout)
	t := time.AfterFunc(
		tx.retransTimeout,
		func() {
			tx.server.NotifyTransTimeout(TX, tx.id)
		},
	)
	return t
}

func NewRxTransaction(
	server *PfcpServer,
	raddr net.Addr,
	seq uint32,
) *RxTransaction {
	return &RxTransaction{
		server:  server,
		raddr:   raddr,
		seq:     seq,
		id:      fmt.Sprintf("%s-%d", raddr, seq),
		timeout: server.cfg.Pfcp.RetransTimeout * time.Duration(server.cfg.Pfcp.MaxRetrans+1),
		log:     server.log.WithField(logger.FieldTransction, fmt.Sprintf("RxTr:%s(%d)", raddr, seq)),
	}
}

func (rx *RxTransaction) send(rsp message.Message) error {
	rx.log.Debugf("send rsp")

	b := make([]byte, rsp.MarshalLen())
	err := rsp.MarshalTo(b)
	if err != nil {
		return err
	}

	// Start rx timer to delete rx
	rx.msgBuf = b
	rx.timer = rx.startTimer()

	_, err = rx.server.conn.WriteTo(b, rx.raddr)
	if err != nil {
		return err
	}

	return nil
}

// True  - need to handle this req
// False - req already handled
func (rx *RxTransaction) recv(req message.Message) (bool, error) {
	rx.log.Debugf("recv req")
	if len(rx.msgBuf) == 0 { // 如果rx的msgbuf没有数据，则需要处理
		return true, nil
	}

	rx.log.Debugf("recv req: retransmit rsp")
	_, err := rx.server.conn.WriteTo(rx.msgBuf, rx.raddr) // 向远程目标重新发送信息
	if err != nil {
		return false, errors.Wrapf(err, "rxtr[%s] recv", rx.id)
	}
	return false, nil
}

func (rx *RxTransaction) handleTimeout() {
	rx.log.Debugf("timeout, delete rxtr")
	delete(rx.server.rxTrans, rx.id)
}

func (rx *RxTransaction) startTimer() *time.Timer {
	rx.log.Debugf("start timer(%s)", rx.timeout)
	t := time.AfterFunc(
		rx.timeout,
		func() {
			rx.server.NotifyTransTimeout(RX, rx.id)
		},
	)
	return t
}
