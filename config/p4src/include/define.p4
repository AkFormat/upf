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
#ifndef __DEFINE__
#define __DEFINE__


// CPU_PORT specifies the P4 port number associated to controller packet-in and
// packet-out.
#define CPU_PORT 255 

// CPU_CLONE_SESSION_ID specifies the mirroring session for packets to be cloned
// to the CPU port. For cloning to work, the P4Runtime client needs first to
// insert a CloneSessionEntry that maps this session ID to the CPU_PORT.
#define CPU_CLONE_SESSION_ID 99

// Table sizes to be tuned for hardware
#define MAX_PDRS 1024
#define MAX_ROUTES 1024


// Some sizes
#define ETH_HDR_SIZE 14
#define IPV4_HDR_SIZE 20
#define IPV4_MIN_IHL 5
#define UDP_HDR_SIZE 8
#define GTP_HDR_MIN_SIZE 8
#define GTPU_OPTIONS_HDR_BYTES 4
#define GTPU_EXT_PSC_HDR_BYTES 4
// Some field values that would be excessive as enums
const bit<4> IP_VERSION_4 = 4;
const bit<8> DEFAULT_IPV4_TTL = 64;

typedef bit<9>   port_num_t;
typedef bit<48>  mac_addr_t;
typedef bit<32>  ipv4_addr_t;


const bit<16> UDP_PORT_GTPU = 2152; 
const bit<3> GTP_V1 = 0x1; 
const bit<1> GTP_PROTOCOL_TYPE_GTP = 0x1;
const bit<8> GTP_MESSAGE_TYPE_UPDU = 0xff;
const bit<8> GTPU_NEXT_EXT_NONE = 0x0;
const bit<8> GTPU_NEXT_EXT_PSC = 0x85;
const bit<4> GTPU_EXT_PSC_TYPE_DL = 4w0; // Downlink
const bit<4> GTPU_EXT_PSC_TYPE_UL = 4w1; // Uplink
const bit<8> GTPU_EXT_PSC_LEN = 8w1; // 1*4-octets

typedef bit<32> far_info_id_t; // FAR
typedef bit<32> pdr_id_t; // PDR
typedef bit<32> far_id_t; // FAR
typedef bit<32> qer_id_t; // QER
typedef bit<32> bar_id_t; // BAR
typedef bit<32> qfi_t; // QFI
typedef bit<32> net_instance_t; // DNN
typedef bit<32> counter_index_t;
typedef bit<32>  scheduling_priority_t;


typedef bit<32> teid_t; // TUNNAL ID
typedef bit<64> seid_t; // SESSION ID

// F-TEID = (4-byte)TEID + GTP endpoint (gnodeb OR UPF) address
typedef bit<64> fteid_t;

// F-SEID = 8-byte SEID + UPF IP(v4/v6) address
typedef bit<96> fseid_t;

// In hardware the full F-TEID and F-SEIDs should be replaced by shorter
// unique identifiers to reduce memory. The slow path can maintain the
// short ID <--> F-TEID/F-SEID mapping.

const pdr_id_t DEFAULT_PDR_ID = 0;
const far_id_t DEFAULT_FAR_ID = 0;
const qer_id_t DEFAULT_QER_ID = 0;
const qfi_t    DEFAULT_QFI    = 0;
const fseid_t  DEFAULT_FSEID  = 0;

//------------------------------------------------------------------------------
// ENUMS
// These should be exposed to the control plane by P4Runtime.
//------------------------------------------------------------------------------

enum bit<8> GTPUMessageType {
    GPDU = 255
}

enum bit<16> EtherType {
    IPV4 = 0x0800,
    IPV6 = 0x86dd // unused
}

enum bit<8> IpProtocol {
    ICMP    = 1,
    TCP     = 6,
    UDP     = 17
}

enum bit<16> L4Port {
    DHCP_SERV       = 67, // naming this DHCP_SERVER causes a syntax error..
    DHCP_CLIENT     = 68,
    GTP_GPDU        = 2152,
    IPV4_IN_UDP     = 9875 // placeholder. port has not yet been assigned by IANA
}

enum bit<8> Direction {
    UNKNOWN             = 0x0,
    UPLINK              = 0x1,
    DOWNLINK            = 0x2,
    OTHER               = 0x3
};

enum bit<8> InterfaceType { // 修改为和free5gc一致的变量
    UNKNOWN       = 0x9, // 胡乱写的一个数据，应该用不到
    ACCESS        = 0x0,
    CORE          = 0x1,
    N6_LAN        = 0x2, // unused, 可能会用到
    VN_INTERNAL   = 0x4, // unused
    CONTROL_PLANE = 0x3 // N4 and N4-u
}

enum bit<8> TunnelType {
    UNKNOWN = 0x0,
    IP      = 0x1, // unused
    UDP     = 0x2, // unused
    GTPU    = 0x3
}

#endif
