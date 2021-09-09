"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" AVR (ATmega8) Omni completion for Vim
" Copyright (C) 2021 Fabrizio Cabaleiro
" 
" This program is free software: you can redistribute it and/or modify it under
" the terms of the GNU General Public License as published by the Free Software
" Foundation, version 2.
" 
" This program is distributed in the hope that it will be useful, but WITHOUT
" ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
" FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
" details.
" 
" You should have received a copy of the GNU General Public License along with
" this program. If not, see <https://www.gnu.org/licenses/>.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Do not source this file if not under a */AVR/* directory
if match(getcwd(), '\c/avr/') == -1
    finish
endif

function GetEmbeddedJson(file, pattern)
    let fileContent = readfile(a:file)
    let firstLine = index(fileContent, a:pattern."Begin") + 1
    let lastLine = index(fileContent, a:pattern."End") - 1
    return json_decode(join(fileContent[firstLine:lastLine]))
endfunction

let g:IS = GetEmbeddedJson(expand('<sfile>'), "InstructionSetJson")

function! SynToList(group)
   redir => content
   silent exec "syntax list ".a:group
   redir END
   return filter(split(content, '[ \n]'), 'v:val != ""')[6:-4]
endfunction

function! AVR_Omni(findstart, base)
   if(a:findstart)
      let line = getline(".")
      let col = col(".") - 1
      while col > 0 && line[col - 1] =~ '\a'
         let col -= 1
      endwhile
      return col
   endif
   let opCodes = sort(SynToList("avrOpcode"))
   let ic = &ignorecase

   " Filter opcodes in case insensitive way
   set ignorecase
   if(!exists("g:avr_omni_match_any") || !g:avr_omni_match_any)
      let match_prefix = "^"
   else
      let match_prefix = ""
   endif
   call filter(opCodes, 'v:val =~ match_prefix.a:base')
   if !ic
      set noignorecase
   endif

   " Convert the result to upper/lower case based on a:base
   if match(a:base[0], '[a-z]') >= 0
      call map(opCodes, 'tolower(v:val)')
   else
      call map(opCodes, 'toupper(v:val)')
   endif

   let rtv = []
   for w in opCodes
      let key = toupper(w)
      if !has_key(g:IS, key)
         continue
      endif
      let d = {}
      let d.word = w
      "let d.abbr = "abbr ".w
      if type(g:IS[key].desc) == v:t_list
         let d.menu = g:IS[key].desc[0]
      else
         let d.menu = g:IS[key].desc
      endif
      let d.info = g:IS[key].type."; "
      let d.info .= "Flags ".g:IS[key].flags."; "
      let d.info .= "Clocks ".g:IS[key].clks."\n"
      " Line wrapping hides preview lines, so, cut them at the window width
      " -5 for prefix
      let width = winwidth(winnr()) - (&number * &numberwidth) - 5
      let d.info .= "Des ".string(g:IS[key].desc)[0:width]."\n"
      let d.info .= "Opd ".string(g:IS[key].Operands)[0:width]."\n"
      let d.info .= "Opc ".string(g:IS[key].Op)[0:width]."\n"
      call add(rtv, d)
   endfor
   return rtv
endfunction

autocmd InsertLeave,CompleteDone * if pumvisible() == 0 | pclose | endif
set omnifunc=AVR_Omni

finish

InstructionSetJsonBegin
{
    "ADD": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Add two Registers",
        "Op": "Rd  <-  Rd + Rr",
        "flags": "Z, C, N, V, H",
        "clks": "1"
    },
    "ADC": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Add with Carry two Registers",
        "Op": "Rd  <-  Rd + Rr + C",
        "flags": "Z, C, N, V, H",
        "clks": "1"
    },
    "ADIW": {
        "type": "ARITH LOGIC",
        "Operands": "Rdl,K",
        "desc": "Add Immediate to Word",
        "Op": "Rdh:Rdl  <-  Rdh:Rdl + K",
        "flags": "Z, C, N, V, S",
        "clks": "2"
    },
    "SUB": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Subtract two Registers",
        "Op": "Rd  <-  Rd - Rr",
        "flags": "Z, C, N, V, H",
        "clks": "1"
    },
    "SUBI": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, K",
        "desc": "Subtract Constant from Register",
        "Op": "Rd  <-  Rd - K",
        "flags": "Z, C, N, V, H",
        "clks": "1"
    },
    "SBC": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Subtract with Carry two Registers",
        "Op": "Rd  <-  Rd - Rr - C",
        "flags": "Z, C, N, V, H",
        "clks": "1"
    },
    "SBCI": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, K",
        "desc": "Subtract with Carry Constant from Reg.",
        "Op": "Rd  <-  Rd - K - C",
        "flags": "Z, C, N ,V, H",
        "clks": "1"
    },
    "SBIW": {
        "type": "ARITH LOGIC",
        "Operands": "Rdl,K",
        "desc": "Subtract Immediate from Word",
        "Op": "Rdh:Rdl  <-  Rdh:Rdl - K",
        "flags": "Z, C, N, V, S",
        "clks": "2"
    },
    "AND": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Logical AND Registers",
        "Op": "Rd  <- Rd * Rr",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "ANDI": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, K",
        "desc": "Logical AND Register and Constant",
        "Op": "Rd  <-  Rd * K",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "OR": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Logical OR Registers",
        "Op": "Rd  <-  Rd v Rr",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "ORI": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, K",
        "desc": "Logical OR Register and Constant",
        "Op": "Rd  <- Rd v K",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "EOR": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Exclusive OR Registers",
        "Op": "Rd  <-  Rd ^ Rr",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "COM": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "One's Complement",
        "Op": "Rd  <-  0xFF - Rd",
        "flags": "Z, C, N, V",
        "clks": "1"
    },
    "NEG": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "Two's Complement",
        "Op": "Rd  <-  0x00 - Rd",
        "flags": "Z, C, N, V, H",
        "clks": "1"
    },
    "SBR": {
        "type": "ARITH LOGIC",
        "Operands": "Rd,K",
        "desc": "Set Bit(s) in Register",
        "Op": "Rd  <-  Rd v K",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "CBR": {
        "type": "ARITH LOGIC",
        "Operands": "Rd,K",
        "desc": "Clear Bit(s) in Register",
        "Op": "Rd  <-  Rd * (0xFF - K)",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "INC": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "Increment",
        "Op": "Rd  <-  Rd + 1",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "DEC": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "Decrement",
        "Op": "Rd  <-  Rd - 1",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "TST": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "Test for Zero or Minus",
        "Op": "Rd  <-  Rd * Rd",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "CLR": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "Clear Register",
        "Op": "Rd  <-  Rd ^ Rd",
        "flags": "Z, N, V",
        "clks": "1"
    },
    "SER": {
        "type": "ARITH LOGIC",
        "Operands": "Rd",
        "desc": "Set Register",
        "Op": "Rd  <-  0xFF",
        "flags": "None",
        "clks": "1"
    },
    "MUL": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Multiply Unsigned",
        "Op": "R1:R0  <-  Rd x Rr",
        "flags": "Z, C",
        "clks": "2"
    },
    "MULS": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Multiply Signed",
        "Op": "R1:R0  <-  Rd x Rr",
        "flags": "Z, C",
        "clks": "2"
    },
    "MULSU": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Multiply Signed with Unsigned",
        "Op": "R1:R0  <-  Rd x Rr",
        "flags": "Z, C",
        "clks": "2"
    },
    "FMUL": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Fractional Multiply Unsigned",
        "Op": "R1:R0  <-  (Rd x Rr) << 1",
        "flags": "Z, C",
        "clks": "2"
    },
    "FMULS": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Fractional Multiply Signed",
        "Op": "R1:R0  <-  (Rd x Rr) << 1",
        "flags": "Z, C",
        "clks": "2"
    },
    "FMULSU": {
        "type": "ARITH LOGIC",
        "Operands": "Rd, Rr",
        "desc": "Fractional Multiply Signed with Unsigned",
        "Op": "R1:R0  <-  (Rd x Rr) << 1",
        "flags": "Z, C",
        "clks": "2"
    },
    "RJMP": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Relative Jump",
        "Op": "PC <-  PC + k + 1",
        "flags": "None",
        "clks": "2"
    },
    "IJMP": {
        "type": "BRACH",
        "Operands": "",
        "desc": "Indirect Jump to (Z)",
        "Op": "PC  <-  Z",
        "flags": "None",
        "clks": "2"
    },
    "RCALL": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Relative Subroutine Call",
        "Op": "PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "3"
    },
    "ICALL": {
        "type": "BRACH",
        "Operands": "",
        "desc": "Indirect Call to (Z)",
        "Op": "PC  <-  Z",
        "flags": "None",
        "clks": "3"
    },
    "RET": {
        "type": "BRACH",
        "Operands": "",
        "desc": "Subroutine Return",
        "Op": "PC  <-  STACK",
        "flags": "None",
        "clks": "4"
    },
    "RETI": {
        "type": "BRACH",
        "Operands": "",
        "desc": "Interrupt Return",
        "Op": "PC  <-  STACK",
        "flags": "I",
        "clks": "4"
    },
    "CPSE": {
        "type": "BRACH",
        "Operands": "Rd,Rr",
        "desc": "Compare, Skip if Equal",
        "Op": "if (Rd = Rr) PC <-  PC + 2 or 3",
        "flags": "None",
        "clks": "1/2/3"
    },
    "CP": {
        "type": "BRACH",
        "Operands": "Rd,Rr",
        "desc": "Compare",
        "Op": "Rd - Rr",
        "flags": "Z, N, V, C, H",
        "clks": "1"
    },
    "CPC": {
        "type": "BRACH",
        "Operands": "Rd,Rr",
        "desc": "Compare with Carry",
        "Op": "Rd - Rr - C",
        "flags": "Z, N, V, C, H",
        "clks": "1"
    },
    "CPI": {
        "type": "BRACH",
        "Operands": "Rd,K",
        "desc": "Compare Register with Immediate",
        "Op": "Rd - K",
        "flags": "Z, N, V, C, H",
        "clks": "1"
    },
    "SBRC": {
        "type": "BRACH",
        "Operands": "Rr, b",
        "desc": "Skip if Bit in Register Cleared",
        "Op": "if (Rr(b)=0) PC  <-  PC + 2 or 3",
        "flags": "None",
        "clks": "1/2/3"
    },
    "SBRS": {
        "type": "BRACH",
        "Operands": "Rr, b",
        "desc": "Skip if Bit in Register is Set",
        "Op": "if (Rr(b)=1) PC  <-  PC + 2 or 3",
        "flags": "None",
        "clks": "1/2/3"
    },
    "SBIC": {
        "type": "BRACH",
        "Operands": "P, b",
        "desc": "Skip if Bit in I/O Register Cleared",
        "Op": "if (P(b)=0) PC  <-  PC + 2 or 3",
        "flags": "None",
        "clks": "1/2/3"
    },
    "SBIS": {
        "type": "BRACH",
        "Operands": "P, b",
        "desc": "Skip if Bit in I/O Register is Set",
        "Op": "if (P(b)=1) PC  <-  PC + 2 or 3",
        "flags": "None",
        "clks": "1/2/3"
    },
    "BRBS": {
        "type": "BRACH",
        "Operands": "s, k",
        "desc": "Branch if Status Flag Set",
        "Op": "if (SREG(s) = 1) then PC <- PC+k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRBC": {
        "type": "BRACH",
        "Operands": "s, k",
        "desc": "Branch if Status Flag Cleared",
        "Op": "if (SREG(s) = 0) then PC <- PC+k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BREQ": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Equal",
        "Op": "if (Z = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRNE": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Not Equal",
        "Op": "if (Z = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRCS": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Carry Set",
        "Op": "if (C = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRCC": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Carry Cleared",
        "Op": "if (C = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRSH": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Same or Higher",
        "Op": "if (C = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRLO": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Lower",
        "Op": "if (C = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRMI": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Minus",
        "Op": "if (N = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRPL": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Plus",
        "Op": "if (N = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRGE": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Greater or Equal, Signed",
        "Op": "if (N ^ V= 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRLT": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Less Than Zero, Signed",
        "Op": "if (N ^ V= 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRHS": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Half Carry Flag Set",
        "Op": "if (H = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRHC": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Half Carry Flag Cleared",
        "Op": "if (H = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRTS": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if T Flag Set",
        "Op": "if (T = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRTC": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if T Flag Cleared",
        "Op": "if (T = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRVS": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Overflow Flag is Set",
        "Op": "if (V = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRVC": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Overflow Flag is Cleared",
        "Op": "if (V = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRIE": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Interrupt Enabled",
        "Op": "if ( I = 1) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "BRID": {
        "type": "BRACH",
        "Operands": "k",
        "desc": "Branch if Interrupt Disabled",
        "Op": "if ( I = 0) then PC  <-  PC + k + 1",
        "flags": "None",
        "clks": "1/2"
    },
    "MOV": {
        "type": "DATA TRANSF",
        "Operands": "Rd, Rr",
        "desc": "Move Between Registers",
        "Op": "Rd  <-  Rr",
        "flags": "None",
        "clks": "1"
    },
    "MOVW": {
        "type": "DATA TRANSF",
        "Operands": "Rd, Rr",
        "desc": "Copy Register Word",
        "Op": "Rd+1:Rd  <-  Rr+1:Rr",
        "flags": "None",
        "clks": "1"
    },
    "LDI": {
        "type": "DATA TRANSF",
        "Operands": "Rd, K",
        "desc": "Load Immediate",
        "Op": "Rd  <-  K",
        "flags": "None",
        "clks": "1"
    },
    "LD": {
        "type": "DATA TRANSF",
        "Operands": [
            "Rd, X",
            "Rd, X+",
            "Rd, - X",
            "Rd, Y",
            "Rd, Y+",
            "Rd, - Y",
            "Rd, Z",
            "Rd, Z+",
            "Rd, -Z"
        ],
        "desc": [
            "Load Indirect",
            "Load Indirect and Post-Inc.",
            "Load Indirect and Pre-Dec.",
            "Load Indirect",
            "Load Indirect and Post-Inc.",
            "Load Indirect and Pre-Dec.",
            "Load Indirect",
            "Load Indirect and Post-Inc.",
            "Load Indirect and Pre-Dec."
        ],
        "Op": [
            "Rd  <-  (X)",
            "Rd  <-  (X), X  <-  X + 1",
            "X  <-  X - 1, Rd  <-  (X)",
            "Rd  <-  (Y)",
            "Rd  <-  (Y), Y  <-  Y + 1",
            "Y  <-  Y - 1, Rd  <-  (Y)",
            "Rd  <-  (Z)",
            "Rd  <-  (Z), Z  <-  Z+1",
            "Z  <-  Z - 1, Rd  <-  (Z)"
        ],
        "flags": "None",
        "clks": "2"
    },
    "LDD": {
        "type": "DATA TRANSF",
        "Operands": [
            "Rd,Y+q",
            "Rd, Z+q"
        ],
        "desc": "Load Indirect with Displacement",
        "Op": [
            "Rd  <-  (Y + q)",
            "Rd  <-  (Z + q)"
        ],
        "flags": "None",
        "clks": "2"
    },
    "LDS": {
        "type": "DATA TRANSF",
        "Operands": "Rd, k",
        "desc": "Load Direct from SRAM",
        "Op": "Rd  <-  (k)",
        "flags": "None",
        "clks": "2"
    },
    "ST": {
        "type": "DATA TRANSF",
        "Operands": [
            "X, Rr",
            "X+, Rr",
            "- X, Rr",
            "Y, Rr",
            "Y+, Rr",
            "- Y, Rr",
            "Z, Rr",
            "Z+, Rr",
            "-Z, Rr"
        ],
        "desc": [
            "Store Indirect",
            "Store Indirect and Post-Inc.",
            "Store Indirect and Pre-Dec.",
            "Store Indirect",
            "Store Indirect and Post-Inc.",
            "Store Indirect and Pre-Dec.",
            "Store Indirect",
            "Store Indirect and Post-Inc.",
            "Store Indirect and Pre-Dec."
        ],
        "Op": [
            "(X) <-  Rr",
            "(X) <-  Rr, X  <-  X + 1",
            "X  <-  X - 1, (X)  <-  Rr",
            "(Y)  <-  Rr",
            "(Y)  <-  Rr, Y  <-  Y + 1",
            "Y  <-  Y - 1, (Y)  <-  Rr",
            "(Z)  <-  Rr",
            "(Z)  <-  Rr, Z  <-  Z + 1",
            "Z  <-  Z - 1, (Z)  <-  Rr"
        ],
        "flags": "None",
        "clks": "2"
    },
    "STD": {
        "type": "DATA TRANSF",
        "Operands": [
            "Y+q,Rr",
            "Z+q,Rr"
        ],
        "desc": "Store Indirect with Displacement",
        "Op": [
            "(Y + q)  <-  Rr",
            "(Z + q)  <-  Rr"
        ],
        "flags": "None",
        "clks": "2"
    },
    "STS": {
        "type": "DATA TRANSF",
        "Operands": "k, Rr",
        "desc": "Store Direct to SRAM",
        "Op": "(k)  <-  Rr",
        "flags": "None",
        "clks": "2"
    },
    "LPM": {
        "type": "DATA TRANSF",
        "Operands": [
            "",
            "Rd, Z",
            "Rd, Z+"
        ],
        "desc": [
            "Load Program Memory",
            "Load Program Memory",
            "Load Program Memory and Post-Inc"
        ],
        "Op": [
            "R0  <-  (Z)",
            "Rd  <-  (Z)",
            "Rd  <-  (Z), Z  <-  Z+1"
        ],
        "flags": "None",
        "clks": "3"
    },
    "SPM": {
        "type": "DATA TRANSF",
        "Operands": "",
        "desc": "Store Program Memory",
        "Op": "(Z)  <-  R1:R0",
        "flags": "None",
        "clks": "-"
    },
    "IN": {
        "type": "DATA TRANSF",
        "Operands": "Rd, P",
        "desc": "In Port",
        "Op": "Rd  <-  P",
        "flags": "None",
        "clks": "1"
    },
    "OUT": {
        "type": "DATA TRANSF",
        "Operands": "P, Rr",
        "desc": "Out Port",
        "Op": "P  <-  Rr",
        "flags": "None",
        "clks": "1"
    },
    "PUSH": {
        "type": "DATA TRANSF",
        "Operands": "Rr",
        "desc": "Push Register on Stack",
        "Op": "STACK  <-  Rr",
        "flags": "None",
        "clks": "2"
    },
    "POP": {
        "type": "DATA TRANSF",
        "Operands": "Rd",
        "desc": "Pop Register from Stack",
        "Op": "Rd  <-  STACK",
        "flags": "None",
        "clks": "2"
    },
    "SBI": {
        "type": "BIT",
        "Operands": "P,b",
        "desc": "Set Bit in I/O Register",
        "Op": "I/O(P,b)  <-  1",
        "flags": "None",
        "clks": "2"
    },
    "CBI": {
        "type": "BIT",
        "Operands": "P,b",
        "desc": "Clear Bit in I/O Register",
        "Op": "I/O(P,b)  <-  0",
        "flags": "None",
        "clks": "2"
    },
    "LSL": {
        "type": "BIT",
        "Operands": "Rd",
        "desc": "Logical Shift Left",
        "Op": "Rd(n+1)  <-  Rd(n), Rd(0)  <-  0",
        "flags": "Z, C, N, V",
        "clks": "1"
    },
    "LSR": {
        "type": "BIT",
        "Operands": "Rd",
        "desc": "Logical Shift Right",
        "Op": "Rd(n)  <-  Rd(n+1), Rd(7)  <-  0",
        "flags": "Z, C, N, V",
        "clks": "1"
    },
    "ROL": {
        "type": "BIT",
        "Operands": "Rd",
        "desc": "Rotate Left Through Carry",
        "Op": "Rd(0) <- C,Rd(n+1) <-  Rd(n),C <- Rd(7)",
        "flags": "Z, C, N, V",
        "clks": "1"
    },
    "ROR": {
        "type": "BIT",
        "Operands": "Rd",
        "desc": "Rotate Right Through Carry",
        "Op": "Rd(7) <- C,Rd(n) <-  Rd(n+1),C <- Rd(0)",
        "flags": "Z, C, N, V",
        "clks": "1"
    },
    "ASR": {
        "type": "BIT",
        "Operands": "Rd",
        "desc": "Arithmetic Shift Right",
        "Op": "Rd(n)  <-  Rd(n+1), n=0..6",
        "flags": "Z, C, N, V",
        "clks": "1"
    },
    "SWAP": {
        "type": "BIT",
        "Operands": "Rd",
        "desc": "Swap Nibbles",
        "Op": "Rd(3..0) <- Rd(7..4),Rd(7..4) <- Rd(3..0)",
        "flags": "None",
        "clks": "1"
    },
    "BSET": {
        "type": "BIT",
        "Operands": "s",
        "desc": "Flag Set",
        "Op": "SREG(s)  <-  1",
        "flags": "SREG(s)",
        "clks": "1"
    },
    "BCLR": {
        "type": "BIT",
        "Operands": "s",
        "desc": "Flag Clear",
        "Op": "SREG(s)  <-  0",
        "flags": "SREG(s)",
        "clks": "1"
    },
    "BST": {
        "type": "BIT",
        "Operands": "Rr, b",
        "desc": "Bit Store from Register to T",
        "Op": "T  <-  Rr(b)",
        "flags": "T",
        "clks": "1"
    },
    "BLD": {
        "type": "BIT",
        "Operands": "Rd, b",
        "desc": "Bit load from T to Register",
        "Op": "Rd(b)  <-  T",
        "flags": "None",
        "clks": "1"
    },
    "SEC": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set Carry",
        "Op": "C <- 1",
        "flags": "C",
        "clks": "1"
    },
    "CLC": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear Carry",
        "Op": "C <- 0",
        "flags": "C",
        "clks": "1"
    },
    "SEN": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set Negative Flag",
        "Op": "N <- 1",
        "flags": "N",
        "clks": "1"
    },
    "CLN": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear Negative Flag",
        "Op": "N <- 0",
        "flags": "N",
        "clks": "1"
    },
    "SEZ": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set Zero Flag",
        "Op": "Z <- 1",
        "flags": "Z",
        "clks": "1"
    },
    "CLZ": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear Zero Flag",
        "Op": "Z <- 0",
        "flags": "Z",
        "clks": "1"
    },
    "SEI": {
        "type": "BIT",
        "Operands": "",
        "desc": "Global Interrupt Enable",
        "Op": "I <- 1",
        "flags": "I",
        "clks": "1"
    },
    "CLI": {
        "type": "BIT",
        "Operands": "",
        "desc": "Global Interrupt Disable",
        "Op": "I <-  0",
        "flags": "I",
        "clks": "1"
    },
    "SES": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set Signed Test Flag",
        "Op": "S <- 1",
        "flags": "S",
        "clks": "1"
    },
    "CLS": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear Signed Test Flag",
        "Op": "S <- 0",
        "flags": "S",
        "clks": "1"
    },
    "SEV": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set Twos Complement Overflow.",
        "Op": "V <- 1",
        "flags": "V",
        "clks": "1"
    },
    "CLV": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear Twos Complement Overflow",
        "Op": "V <- 0",
        "flags": "V",
        "clks": "1"
    },
    "SET": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set T in SREG",
        "Op": "T <- 1",
        "flags": "T",
        "clks": "1"
    },
    "CLT": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear T in SREG",
        "Op": "T <- 0",
        "flags": "T",
        "clks": "1"
    },
    "SEH": {
        "type": "BIT",
        "Operands": "",
        "desc": "Set Half Carry Flag in SREG",
        "Op": "H <- 1",
        "flags": "H",
        "clks": "1"
    },
    "CLH": {
        "type": "BIT",
        "Operands": "",
        "desc": "Clear Half Carry Flag in SREG",
        "Op": "H <- 0",
        "flags": "H",
        "clks": "1"
    },
    "NOP": {
        "type": "MCU CTRL",
        "Operands": "",
        "desc": "No Operation",
        "Op": "",
        "flags": "None",
        "clks": "1"
    },
    "SLEEP": {
        "type": "MCU CTRL",
        "Operands": "",
        "desc": "Sleep",
        "Op": "(see specific descr. for Sleep function)",
        "flags": "None",
        "clks": "1"
    },
    "WDR": {
        "type": "MCU CTRL",
        "Operands": "",
        "desc": "Watchdog Reset",
        "Op": "(see specific descr. for WDR/timer)",
        "flags": "None",
        "clks": "1"
    }
}
InstructionSetJsonEnd
