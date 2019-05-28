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

typedef ap_uint<8> portData_t;
typedef ap_axis<8,1,1,5> axiData_t;
typedef hls::stream<axiData_t> axiStream_t;

void Adapter_twStream_wrapper(axiStream_t& in, portData_t& out) {
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS INTERFACE axis port=in
#pragma HLS INTERFACE ap_hs port=out
   portData_t inTmp = in.read().data;
   out = inTmp;
}
