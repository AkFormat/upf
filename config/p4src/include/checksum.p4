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
//#ifndef __CHECKSUM__
// #define __CHECKSUM__

#include "define.p4"
#include "header.p4"

//------------------------------------------------------------------------------
// PRE-INGRESS CHECKSUM VERIFICATION
//------------------------------------------------------------------------------
control VerifyChecksumImpl(inout parsed_headers_t hdr,
                           inout local_metadata_t meta)
{
    apply {
        verify_checksum(hdr.ipv4.isValid(),
            {
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.dscp,
                hdr.ipv4.ecn,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.proto,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            },
            hdr.ipv4.checksum,
            HashAlgorithm.csum16
        );
        verify_checksum(hdr.outer_ipv4.isValid(),
            {
                hdr.outer_ipv4.version,
                hdr.outer_ipv4.ihl,
                hdr.outer_ipv4.dscp,
                hdr.outer_ipv4.ecn,
                hdr.outer_ipv4.total_len,
                hdr.outer_ipv4.identification,
                hdr.outer_ipv4.flags,
                hdr.outer_ipv4.frag_offset,
                hdr.outer_ipv4.ttl,
                hdr.outer_ipv4.proto,
                hdr.outer_ipv4.src_addr,
                hdr.outer_ipv4.dst_addr
            },
            hdr.outer_ipv4.checksum,
            HashAlgorithm.csum16
        );
        // TODO: add checksum verification for gtpu (if possible), inner_udp, inner_tcp
    }
}

//------------------------------------------------------------------------------
// CHECKSUM COMPUTATION
//------------------------------------------------------------------------------
control ComputeChecksumImpl(inout parsed_headers_t hdr,
                            inout local_metadata_t local_meta)
{
    apply {
        // Compute Outer IPv4 checksum
        update_checksum(hdr.outer_ipv4.isValid(),{
                hdr.outer_ipv4.version,
                hdr.outer_ipv4.ihl,
                hdr.outer_ipv4.dscp,
                hdr.outer_ipv4.ecn,
                hdr.outer_ipv4.total_len,
                hdr.outer_ipv4.identification,
                hdr.outer_ipv4.flags,
                hdr.outer_ipv4.frag_offset,
                hdr.outer_ipv4.ttl,
                hdr.outer_ipv4.proto,
                hdr.outer_ipv4.src_addr,
                hdr.outer_ipv4.dst_addr
            },
            hdr.outer_ipv4.checksum,
            HashAlgorithm.csum16
        );
        
        // Outer UDP checksum currently remains 0, 
        // which is legal for IPv4

        // Compute IPv4 checksum
        update_checksum(hdr.ipv4.isValid(),{
                hdr.ipv4.version,
                hdr.ipv4.ihl,
                hdr.ipv4.dscp,
                hdr.ipv4.ecn,
                hdr.ipv4.total_len,
                hdr.ipv4.identification,
                hdr.ipv4.flags,
                hdr.ipv4.frag_offset,
                hdr.ipv4.ttl,
                hdr.ipv4.proto,
                hdr.ipv4.src_addr,
                hdr.ipv4.dst_addr
            },
            hdr.ipv4.checksum,
            HashAlgorithm.csum16
        );
    }
}

//#endif
