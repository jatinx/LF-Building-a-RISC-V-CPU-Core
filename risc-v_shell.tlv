\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v_includes/1d1023ccf8e7b0a8cf8e8fc4f0a823ebb61008e3/risc-v_defs.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   m4_test_prog()
   m4_define(['M4_MAX_CYC'], 60)
   //---------------------------------------------------------------------------------



\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   // Entire CPU executes in 1 clock cycle
   
   $reset = *reset;
   
   // Program Counter
   $next_pc[31:0] = $reset ? 32'd0 : $taken_br;
   $pc[31:0] = >>1$next_pc;
   
   // Get IMem
   // TODO Read enable counter
   // TODO Learn about macros
   `READONLY_MEM($pc, $$instr[31:0]);
   
   // Decode logic
   // RV32I - last two bits have to be 11 for any valid instruction
   // $is_valid_instr = $instr[1:0] == 2'b11;
   
   // Type of instr classification from opcode
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   
   // Is Immediate instruction
   $is_i_instr = $instr[6:2] == 5'b00000 | $instr[6:2] == 5'b00001
                 | $instr[6:2] == 5'b00100 | $instr[6:2] == 5'b00110
                 | $instr[6:2] == 5'b11001;
   
   // Is register instruction
   $is_r_instr = $instr[6:2] == 5'b01011 | $instr[6:2] == 5'b01100
                 | $instr[6:2] == 5'b01110 | $instr[6:2] == 5'b10100;
   
   // Store instruction
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   
   // Is branch
   $is_b_instr = $instr[6:2] == 5'b11000;
   
   // Is Jump
   $is_j_instr = $instr[6:2] == 5'b11011;
   
   // Fields from instruction
   // Source register 1
   $rs1[4:0] = $instr[19:15];
   $rs1_valid = $is_r_instr | $is_i_instr | $is_s_instr | $is_b_instr;
   
   // Source register 2
   $rs2[4:0] = $instr[24:20];
   $rs2_valid = $is_r_instr | $is_s_instr | $is_b_instr;
   
   // Destination register
   $rd[4:0] = $instr[11:7];
   // If the destination is 0, do not perform write
   $rd_valid = ( $is_r_instr | $is_i_instr | $is_u_instr | $is_j_instr ) & ( $rd != 5'b0 );
   
   $opcode[6:0] = $instr[6:0];
   
   $funct3[2:0] = $instr[14:12];
   // $funct3_valid = $is_r_instr | $is_i_instr | $is_s_instr | $is_b_instr;
   
   $imm[31:0] = $is_i_instr ? { {21{$instr[31]}}, $instr[30:20] } :
                $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:8], $instr[7] } :
                $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0 } :
                $is_u_instr ? { $instr[31], $instr[30:20], $instr[19:12], 12'b0 } :
                $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:25], $instr[24:21], 1'b0 } :
                32'b0;
   $imm_valid = $is_i_instr | $is_s_instr | $is_b_instr | $is_u_instr | $is_j_instr;
   
   // $funct7[6:0] = $instr[31:25];
   // $funct7_valid = $is_r_instr;
   
   $dec_bits[10:0] = { $instr[30], $funct3, $opcode };
   
   // Figure out which instruction
   $is_beq = $dec_bits ==? 11'bx_000_1100011; // Branch on Equal
   $is_bne = $dec_bits ==? 11'bx_001_1100011; // Branch on not Equal
   $is_blt = $dec_bits ==? 11'bx_100_1100011; // Branch on less than
   $is_bge = $dec_bits ==? 11'bx_101_1100011; // Branch on greater than equal
   $is_bltu = $dec_bits ==? 11'bx_110_1100011; // Branch on less than unsigned
   $is_bgeu = $dec_bits ==? 11'bx_111_1100011; // Branch on greater than equal unsigned
   $is_addi = $dec_bits ==? 11'bx_000_0010011; // Add immediate
   $is_add = $dec_bits == 11'b0_000_0110011; // Add
   $is_and = $dec_bits == 11'b0_111_0110011; // AND
   $is_or = $dec_bits == 11'b0_110_0110011; // OR
   $is_sra = $dec_bits == 11'b1_101_0110011; // Shift Arith Right = preserve MSB
   $is_srl = $dec_bits == 11'b0_101_0110011; // Shift Logical Right = gg MSB
   $is_xor = $dec_bits == 11'b0_100_0110011; // XOR
   $is_sltu = $dec_bits == 11'b0_011_0110011; // Set on Less than
   $is_slt = $dec_bits == 11'b0_010_0110011; // Set on Less than
   $is_sll = $dec_bits == 11'b0_001_0110011; // Logical Left Shift
   $is_sub = $dec_bits == 11'b1_000_0110011; // Sub
   $is_srai = $dec_bits == 11'b1_101_0010011; // Signed Arith Right Shift Imm
   $is_srli = $dec_bits == 11'b0_101_0010011; // Signed logical Right Shift Imm
   $is_slli = $dec_bits == 11'b0_001_0010011; // Signed logical Left Shift Imm
   $is_andi = $dec_bits ==? 11'bx_111_0010011; // And Immediate
   $is_ori = $dec_bits ==? 11'bx_110_0010011; // OR Immediate
   $is_xori = $dec_bits ==? 11'bx_100_0010011; // XOR Immediate
   $is_sltiu = $dec_bits ==? 11'bx_011_0010011; // Set on Less Than Immediate Unsigned
   $is_slti = $dec_bits ==? 11'bx_010_0010011; // Set on Less Than Immediate
   $is_jalr = $dec_bits ==? 11'bx_000_1100111; // Jump to address and place return address in rd
   $is_jal = $dec_bits ==? 11'bx_xxx_1101111; // Jump to address and place return address in rd
   $is_auipc = $dec_bits ==? 11'bx_xxx_0010111; // add upper immediate to pc
   $is_lui = $dec_bits ==? 11'bx_xxx_0110111; // load upper immediate
   
   $is_load = $dec_bits ==? 11'bx_xxx_0000011; // Is load instruction
   
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value};
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];
   
   $result[31:0] = $is_addi ? $src1_value + $imm :
                   $is_add ? $src1_value + $src2_value :
                   $is_andi ? $src1_value & $imm :
                   $is_ori ? $src1_value | $imm :
                   $is_xori ? $src1_value ^ $imm :
                   $is_slli ? $src1_value << $imm[5:0] :
                   $is_srli ? $src1_value >> $imm[5:0] :
                   $is_and ? $src1_value & $src2_value :
                   $is_or ? $src1_value | $src2_value :
                   $is_xor ? $src1_value ^ $src2_value :
                   $is_sub ? $src1_value - $src2_value :
                   $is_sll ? $src1_value << $src2_value[4:0] :
                   $is_srl ? $src1_value >> $src2_value[4:0] :
                   $is_sltu ? $sltu_rslt :
                   $is_sltiu ? $sltiu_rslt :
                   $is_lui ? {$imm[31:12], 12'b0} :
                   $is_auipc ? $pc + $imm :
                   $is_jal ? $pc + 32'd4 :
                   $is_jalr ? $pc + 32'd4 :
                   $is_slt ? (($src1_value[31] == $src2_value[31]) ? $sltu_rslt : {31'b0, $src1_value[31]}) :
                   $is_slti ? (($src1_value[31] == $imm[31]) ? $sltiu_rslt : {31'b0, $src1_value[31]}) :
                   $is_sra ? $sra_rslt[31:0] :
                   $is_srai ? $srai_rslt[31:0] :
                   $is_load | $is_s_instr ? $src1_value + $imm :
                   32'b0;
   
   $result_write[31:0] = $is_load ? $ld_data[31:0] : $result;
   
   // $jalr_tgt_pc[31:0] = $src1_value + $imm;
   
   // If its a branch
   $is_b = $dec_bits ==? 11'bx_xxx_1100011;
   
   // Compute hypothetical target pc
   $br_tgt_pc[31:0] = $pc + $imm;
   
   $taken_br[31:0] = $is_b ?
                      $is_blt ?
                           ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) ?
                               $br_tgt_pc : $pc + 32'd4
                    : $is_bge ?
                         ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) ?
                             $br_tgt_pc : $pc + 32'd4
                    : $is_beq ?
                         ($src1_value == $src2_value) ?
                             $br_tgt_pc : $pc + 32'd4
                    : $is_bne ?
                        ($src1_value != $src2_value) ?
                            $br_tgt_pc : $pc + 32'd4
                    : $is_bltu ?
                        ($src1_value < $src2_value) ?
                            $br_tgt_pc : $pc + 32'd4
                    : $is_bgeu ?
                        ($src1_value >= $src2_value) ?
                            $br_tgt_pc : $pc + 32'd4
                    : $pc + 32'd4
               : $is_jal ? $pc + $imm
               : $is_jalr ? $src1_value + $imm
               : $pc + 32'd4;
   
   // Suppress warnings
   `BOGUS_USE($imm_valid)
   // `BOGUS_USE($rd $rd_valid $rs1 $rs1_valid $rs2 $rs2_valid $opcode $funct3 $funct3_valid $imm $imm_valid $is_beq $is_bne $is_blt $is_bge $is_bltu $is_bgeu $is_addi $is_add)
   
   // Assert these to end simulation (before Makerchip cycle limit).
   m4+tb()
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   // Register file 32 bits 32 registers
   m4+rf(32, 32, $reset, $rd_valid, $rd, $result_write, $rs1_valid, $rs1, $src1_value, $rs2_valid, $rs2, $src2_value)
   
   // Memory file
   m4+dmem(32, 32, $reset, $result[6:2], $is_s_instr, $src2_value, $is_load, $$ld_data[31:0])
   
   //m4+rf(32, 32, $reset, $wr_en, $wr_index[4:0], $wr_data[31:0], $rd1_en, $rd1_index[4:0], $rd1_data, $rd2_en, $rd2_index[4:0], $rd2_data)
   //m4+dmem(32, 32, $reset, $addr[4:0], $wr_en, $wr_data[31:0], $rd_en, $rd_data)
   m4+cpu_viz()
\SV
   endmodule