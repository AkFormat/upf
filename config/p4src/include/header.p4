/*
* Copyright 2020-2021 Open Networking Foundation
* Copyright 2021-present Princeton University
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*
*/
#ifndef __HEADERS__
#define __HEADERS__

#include "define.p4"


header ethernet_t {
    mac_addr_t  dst_addr;
    mac_addr_t  src_addr;
    EtherType   ether_type;
}

header ipv4_t {
    bit<4>          version;
    bit<4>          ihl;
    bit<6>          dscp;
    bit<2>          ecn;
    bit<16>         total_len;
    bit<16>         identification;
    bit<3>          flags;
    bit<13>         frag_offset;
    bit<8>          ttl;
    IpProtocol      proto;
    bit<16>         checksum;
    ipv4_addr_t     src_addr;
    ipv4_addr_t     dst_addr;
}

header tcp_t {
    L4Port  sport;
    L4Port  dport;
    bit<32> seq_no;
    bit<32> ack_no;
    bit<4>  data_offset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_t {
    L4Port  sport;
    L4Port  dport;
    bit<16> len;
    bit<16> checksum;
}

header icmp_t {
    bit<8> icmp_type;
    bit<8> icmp_code;
    bit<16> checksum;
    bit<16> identifier;
    bit<16> sequence_number;
    bit<64> timestamp;
}

header gtpu_t {
    bit<3>          version;    /* version */
    bit<1>          pt;         /* protocol type */
    bit<1>          spare;      /* reserved */
    bit<1>          ex_flag;    /* next extension hdr present? */ // 是否有拓展头
    bit<1>          seq_flag;   /* sequence no. */ //是否有序列号
    bit<1>          npdu_flag;  /* n-pdn number present ? */
    GTPUMessageType msgtype;    /* message type */
    bit<16>         msglen;     /* message length */
    teid_t          teid;       /* tunnel endpoint id */
}

// Follows gtpu_t if any of ex_flag, seq_flag, or npdu_flag is 1.
header gtpu_options_t {
    bit<16> seq_num;   /* Sequence number */
    bit<8>  n_pdu_num; /* N-PDU number */
    bit<8>  next_ext;  /* Next exension header */
}

// GTPU extension: PDU Session Container (PSC) -- 3GPP TS 38.415 version 15.2.0 // 拓展协议头
// https://www.etsi.org/deliver/etsi_ts/138400_138499/138415/15.02.00_60/ts_138415v150200p.pdf
header gtpu_ext_psc_t {
    bit<8> len;      /* Length in 4-octet units (common to all extensions) */
    bit<4> type;     /* Uplink or downlink */
    bit<4> spare0;   /* Reserved */
    bit<1> ppp;      /* Paging Policy Presence (UL only, not supported) */
    bit<1> rqi;      /* Reflective QoS Indicator (UL only) */
    bit<6> qfi;      /* QoS Flow Identifier */
    bit<8> next_ext;
}

@controller_header("packet_out")
header packet_out_t {
    bit<8> reserved; // Not used
}

@controller_header("packet_in")
header packet_in_t {
    port_num_t  ingress_port;
    bit<7>      _pad;
}



struct parsed_headers_t {
    packet_out_t  packet_out; // 如果出现了，则证明该数据包需要被正常转发
    packet_in_t   packet_in;  // 如果出现了，则证明：
    ethernet_t ethernet;      // 以太网头
    ipv4_t outer_ipv4;        // 外层IP报文头
    udp_t outer_udp;          // 外层UDP报文头
    gtpu_t gtpu;              // gtp头部
    gtpu_options_t gtpu_options; // gtp头部opetions
    gtpu_ext_psc_t gtpu_ext_psc;
    ipv4_t ipv4; // 普通ipv4报文头，如果没有gtp报头
    udp_t udp;   // 普通udp包，如果没有gtp报头
    tcp_t tcp;   // 普通tcp包，如果没有gtp报头
    icmp_t icmp; // 普通icmp包，如果没有gtp报头
    ipv4_t inner_ipv4; // 内部ipv4报头，如果存在gtp报头
    udp_t inner_udp;   
    tcp_t inner_tcp; 
    icmp_t inner_icmp;
}

//------------------------------------------------------------------------------
// METADATA DEFINITIONS，涉及到QoS规则
//------------------------------------------------------------------------------

// Data associated with a PDR entry, pdr参数数据
struct pdr_metadata_t {
    pdr_id_t id;
    counter_index_t ctr_idx;
    bit<6> tunnel_out_qfi;
}

// Data associated with Buffering and BARs， bar参数数据
struct bar_metadata_t {
    bool needs_buffering;  // 是否需要缓存
    bar_id_t bar_id;  // bar ID
    bit<32> ddn_delay_ms; // unused so far
    bit<32> suggest_pkt_count; // unused so far
}

struct ddn_digest_t {
    fseid_t  fseid;
}


// Data associated with a FAR entry. Loaded by a FAR (except ID which is loaded by a PDR)，FAR参数
struct far_metadata_t {
    far_id_t    id;

    // Buffering, dropping, tunneling etc. are not mutually exclusive.
    // Hence, they should be flags and not different action types.
    bool needs_dropping;
    bool needs_tunneling;
    bool notify_cp;

    TunnelType  tunnel_out_type;
    ipv4_addr_t tunnel_out_src_ipv4_addr;
    ipv4_addr_t tunnel_out_dst_ipv4_addr;
    L4Port      tunnel_out_udp_sport;
    teid_t      tunnel_out_teid;

    ipv4_addr_t next_hop_ip;
}

// The primary metadata structure.
struct local_metadata_t {

    Direction direction;

    @field_list(1)
    bit<9> copy_ingress_port;

    // SEID and F-TEID currently have no use in fast path
    teid_t teid;    // local Tunnel ID.  F-TEID = TEID + GTP endpoint address
    // seid_t seid; // local Session ID. F-SEID = SEID + GTP endpoint address

    // fteid_t fteid;
    fseid_t fseid;

    ipv4_addr_t next_hop_ip; 

    bool needs_gtpu_decap; // 是否需要解gtpu
    bool needs_udp_decap; // unused
    bool needs_vlan_removal; // unused
    bool needs_ext_psc; // used to signal gtpu encap with PSC extension

    InterfaceType src_iface; // 数据包发送方是何种接口
    InterfaceType dst_iface; // unused

    ipv4_addr_t ue_addr;  // ue 地址
    ipv4_addr_t inet_addr; // DNN地址
    L4Port      ue_l4_port; // ue 4层协议端口
    L4Port      inet_l4_port; // 目标端口？

    L4Port      l4_sport; // 4层协议源端口
    L4Port      l4_dport;

    net_instance_t net_instance;

    pdr_metadata_t pdr;
    far_metadata_t far;
    bar_metadata_t bar;
}


#endif
