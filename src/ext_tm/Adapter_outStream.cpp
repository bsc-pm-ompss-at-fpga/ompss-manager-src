/*------------------------------------------------------------------------*/
/*    (C) Copyright 2017-2018 Barcelona Supercomputing Center             */
/*                            Centro Nacional de Supercomputacion         */
/*                                                                        */
/*    This file is part of OmpSs@FPGA toolchain.                          */
/*                                                                        */
/*    This code is free software; you can redistribute it and/or modify   */
/*    it under the terms of the GNU General Public License as published   */
/*    by the Free Software Foundation; either version 3 of the License,   */
/*    or (at your option) any later version.                              */
/*                                                                        */
/*    OmpSs@FPGA toolchain is distributed in the hope that it will be     */
/*    useful, but WITHOUT ANY WARRANTY; without even the implied          */
/*    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    */
/*    See the GNU General Public License for more details.                */
/*                                                                        */
/*    You should have received a copy of the GNU General Public License   */
/*    along with this code. If not, see <www.gnu.org/licenses/>.          */
/*------------------------------------------------------------------------*/

#include <hls_stream.h>
#include <ap_axi_sdata.h>

typedef ap_uint<72> portData_t;
typedef ap_axis<64,1,1,5> axiData_t;
typedef hls::stream<axiData_t> axiStream_t;

void Adapter_outStream_wrapper(volatile portData_t& in, axiStream_t& out) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE ap_hs port=in bundle=in
#pragma HLS INTERFACE axis port=out
#pragma HLS PROTOCOL fixed
   portData_t inTmp = in;
   axiData_t outTmp = {0, 0, 0, 0, 0, 0, 0};
   outTmp.keep = 0xFF;
   outTmp.last = inTmp & 0x3;
   inTmp = inTmp >> 2;
   outTmp.dest = inTmp & 0x3F;
   inTmp = inTmp >> 6;
   outTmp.data = inTmp;
   out.write(outTmp);
}
