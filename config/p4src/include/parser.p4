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
#ifndef __PARSER__
#define __PARSER__

#include "define.p4"
#include "header.p4"


//------------------------------------------------------------------------------
// PARSER
//------------------------------------------------------------------------------
parser ParserImpl (packet_in packet,
                   out parsed_headers_t hdr,
                   inout local_metadata_t local_meta,
                   inout standard_metadata_t std_meta)
{

    // We assume the first header will always be the Ethernet one, unless the
    // the packet is a packet-out coming from the CPU_PORT.
    // 首选判断该数据包是否从控制面发送而来
    state start {
        transition select(std_meta.ingress_port) {
            CPU_PORT: parse_packet_out;
            default: parse_ethernet;
        }
    }
    
    state parse_packet_out {
        packet.extract(hdr.packet_out);
        transition parse_ethernet;
    }

    // 解析 二层包头
    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type){
            EtherType.IPV4: parse_ipv4; // 跳转到IPv4
            default: accept;
        }
    }
    // 解析 Ipv4 
    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.proto) { // ip上层协议
            IpProtocol.UDP:  parse_udp; 
            IpProtocol.TCP:  parse_tcp;
            IpProtocol.ICMP: parse_icmp;
            default: accept;
        }
    }

    // Eventualy add VLAN header parsing

    // 解析外层udp
    state parse_udp {
        packet.extract(hdr.udp);
        // note: this eventually wont work
        local_meta.l4_sport = hdr.udp.sport; // 将l4_sport赋值为外层udp源端口
        local_meta.l4_dport = hdr.udp.dport; // 将l4_dport赋值为外层udp目的端口
        gtpu_t gtpu = packet.lookahead<gtpu_t>(); // 向前看 gtpu_t 大小的数据，并将该数据返回
        // TODO：设置对gtpu的校验
        transition select(hdr.udp.dport, gtpu.version, gtpu.msgtype) {
            (L4Port.IPV4_IN_UDP, _, _): parse_inner_ipv4; // 如果是ipv4 in UDP，则直接解析ipv4
            // Treat GTP control traffic as payload.
            (L4Port.GTP_GPDU, GTP_V1, GTPUMessageType.GPDU): parse_gtpu; // 如果是GTP协议，解析
            default: accept;
        }
    }

    state parse_tcp {
        packet.extract(hdr.tcp);
        local_meta.l4_sport = hdr.tcp.sport;// 将l4_sport赋值为外层tcp源端口
        local_meta.l4_dport = hdr.tcp.dport;// 将l4_dport赋值为外层udp目的端口
        transition accept;
    }

    state parse_icmp {
        packet.extract(hdr.icmp);
        transition accept;
    }

    // 解析GTP-U
    state parse_gtpu {
        packet.extract(hdr.gtpu); 
        local_meta.teid = hdr.gtpu.teid; //记录tedi
        transition select(hdr.gtpu.ex_flag, hdr.gtpu.seq_flag, hdr.gtpu.npdu_flag) { // 根据gtp协议的option来决定下一步
            (0, 0, 0): parse_inner_ipv4; 
            default: parse_gtpu_options;
        }
    }

    state parse_gtpu_options {
        packet.extract(hdr.gtpu_options);
        bit<8> gtpu_ext_len = packet.lookahead<bit<8>>();
        transition select(hdr.gtpu_options.next_ext, gtpu_ext_len) {
            (GTPU_NEXT_EXT_PSC, GTPU_EXT_PSC_LEN): parse_gtpu_ext_psc;
            default: accept;
        }
    }

    state parse_gtpu_ext_psc {
        packet.extract(hdr.gtpu_ext_psc);
        transition select(hdr.gtpu_ext_psc.next_ext) {
            GTPU_NEXT_EXT_NONE: parse_inner_ipv4; // gtp协议到头，开始解析内部协议
            default: accept;
        }
    }

    //-----------------
    // Inner packet
    //-----------------

    state parse_inner_ipv4 {
        packet.extract(hdr.inner_ipv4);
        transition select(hdr.inner_ipv4.proto) {
            IpProtocol.UDP:  parse_inner_udp; 
            IpProtocol.TCP:  parse_inner_tcp;
            IpProtocol.ICMP: parse_inner_icmp;
            default: accept;
        }
    }

    state parse_inner_udp {
        packet.extract(hdr.inner_udp);
        local_meta.l4_sport = hdr.inner_udp.sport; //将l4_sport赋值为内层udp源端口
        local_meta.l4_dport = hdr.inner_udp.dport; //将l4_dport赋值为内层udp目的端口
        transition accept;
    }

    state parse_inner_tcp {
        packet.extract(hdr.inner_tcp);
        local_meta.l4_sport = hdr.inner_tcp.sport;
        local_meta.l4_dport = hdr.inner_tcp.dport;
        transition accept;
    }

    state parse_inner_icmp {
        packet.extract(hdr.inner_icmp);
        transition accept;
    }
}

//------------------------------------------------------------------------------
// DEPARSER
//------------------------------------------------------------------------------
control DeparserImpl(packet_out packet, in parsed_headers_t hdr) {
    apply {
        packet.emit(hdr.packet_in);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.outer_ipv4);
        packet.emit(hdr.outer_udp);
        packet.emit(hdr.gtpu);
        packet.emit(hdr.gtpu_options);
        packet.emit(hdr.gtpu_ext_psc);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.tcp);
        packet.emit(hdr.icmp);
    }
}


#endif
