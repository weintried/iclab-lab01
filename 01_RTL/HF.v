module HF(
    // Input signals
    input [24:0] symbol_freq,
    // Output signals
    output reg [19:0] out_encoded
);

///////////////////////////////////////////////////////////////////////////////
// 1) We will treat each symbol/node as follows:
//    - freq[node] = frequency of this node (up to 8 bits, since sums can exceed 5 bits).
//    - left[node], right[node]: children indices (15 => no child).
//    - symbol_id[node]: which leaf symbol it corresponds to if it's a leaf (0..4 for a..e),
//                       or 7 if it's an internal node.
//    - active[node]: indicates whether this node is in the "priority queue" for merging.
//
//    We'll have up to 9 nodes total:
//      node 0..4 => the 5 leaves (a..e),
//      node 5..8 => internal nodes formed by merging.
//
// 2) Build the Huffman tree by repeatedly merging the two smallest active nodes:
//    - If tie in freq, pick the node whose "lowest leaf symbol" is smaller in alphabetical order.
//    - The "higher-priority" node goes to the left (bit=0), the lower-priority node to the right (bit=1).
//
// 3) After building node 8 (the final root), we do a DFS to find each leaf’s path
//    and produce a 4-bit code (left-padded with 0 if shorter).
///////////////////////////////////////////////////////////////////////////////

//
// We need small helper functions/tasks.
//
integer i;  // used in always block

// Arrays to store node data (indexed 0..8).
// freq can go up to ~155 in worst case (e.g., sum of all 31s), so use 8 or 9 bits.
reg [7:0] freq   [0:8];
reg [3:0] left   [0:8];
reg [3:0] right  [0:8];
reg [2:0] symbol [0:8];  // 0..4 => a..e for leaves, 7 => internal
reg       active [0:8];  // 1 => node is active in the priority queue

// Return the lowest symbol (0..4) found in the subtree rooted at `nd`.
// If nd < 5, it's a leaf with symbol[nd]. If nd >=5, it’s internal, so check children.
function [2:0] getLowestLeafSymbol;
   input [3:0] nd;
begin
   if (nd < 5) begin
       // Leaf node
       getLowestLeafSymbol = symbol[nd]; 
   end
   else begin
       // Internal node
       // Recursively compare children
       if (left[nd] == 4'hF && right[nd] == 4'hF) begin
           // Should never happen for a valid internal node, but just in case
           getLowestLeafSymbol = 3'd7; 
       end
       else if (right[nd] == 4'hF) begin
           // Only a left child
           getLowestLeafSymbol = getLowestLeafSymbol(left[nd]);
       end
       else if (left[nd] == 4'hF) begin
           // Only a right child
           getLowestLeafSymbol = getLowestLeafSymbol(right[nd]);
       end
       else begin
           // Both children exist, pick the smaller of the two
           reg [2:0] lsymL, lsymR;
           lsymL = getLowestLeafSymbol(left[nd]);
           lsymR = getLowestLeafSymbol(right[nd]);
           getLowestLeafSymbol = (lsymL < lsymR) ? lsymL : lsymR;
       end
   end
end
endfunction

// Compare two nodes i, j to see which has "less" priority in the Huffman sense:
//   1) smaller freq
//   2) if tie, smaller "lowest leaf symbol"
function bit lessOrEqual;  // returns 1 if i <= j in priority order
   input [3:0] i, j;
   reg [2:0] li, lj;
begin
   if (freq[i] < freq[j]) begin
       lessOrEqual = 1'b1;
   end
   else if (freq[i] > freq[j]) begin
       lessOrEqual = 1'b0;
   end
   else begin
       // tie in freq => compare the lowest-leaf symbol
       li = getLowestLeafSymbol(i);
       lj = getLowestLeafSymbol(j);
       if (li <= lj)
           lessOrEqual = 1'b1;
       else
           lessOrEqual = 1'b0;
   end
end
endfunction

// Find the two distinct active nodes with the smallest freq (with tie-break).
// We will return indices min1, min2 such that min1 is the highest priority (lowest freq).
task findTwoMin;
   output [3:0] min1;
   output [3:0] min2;
   integer k;
   reg [3:0] candidate [0:8];
   integer count;
begin
   // Collect active nodes into an array 'candidate'.
   count = 0;
   for (k=0; k<9; k=k+1) begin
       if (active[k] == 1'b1) begin
          candidate[count] = k[3:0];
          count = count + 1;
       end
   end

   // We assume count >= 2 always during merges
   // Initialize min1, min2 to the first two
   // then do a small selection pass to find the top two.
   min1 = candidate[0];
   min2 = candidate[1];
   // If needed, swap them so min1 is indeed "less" or equal in priority
   if (!lessOrEqual(min1, min2)) begin
       reg [3:0] tmp;
       tmp = min1; 
       min1 = min2; 
       min2 = tmp;
   end

   // Now check the rest
   for (k=2; k<count; k=k+1) begin
       if (lessOrEqual(candidate[k], min1)) begin
           // new candidate is better than min1, so min2 becomes min1, min1 becomes candidate[k]
           min2 = min1;
           min1 = candidate[k];
       end
       else if (lessOrEqual(candidate[k], min2)) begin
           // new candidate is better than min2 only
           min2 = candidate[k];
       end
   end
end
endtask

// We use a local recursive function that returns both the code and the length
// in up to 8 bits for safety, then we trim/left-pad to 4 bits.
function [11:0] dfs; 
    // return {found_flag, length, code_in_LSBs}
    // found_flag = 1 bit
    // length     = 4 bits
    // code       = up to 7 bits in the LSB area
    input [3:0] currentNode;
    input [3:0] currentDepth;  // how many bits so far
begin
    // If this node is a leaf, check if it matches leafSym
    if (currentNode < 5) begin
        if (symbol[currentNode] == leafSym) begin
        // Found it, code is 0 bits at this level
        dfs = {1'b1, 4'd0, 7'b0}; 
        end
        else begin
        dfs = {1'b0, 4'd0, 7'b0}; 
        end
    end
    else begin
        // Internal node: try left first
        reg [11:0] leftResult, rightResult;
        leftResult  = dfs(left[currentNode],  currentDepth+1);
        if (leftResult[11]) begin
            // found in left subtree => prepend bit '0'
            // leftResult = {found_flag=1, length, codeLSBs}
            // we add 1 to length, shift code << 1
            // leftResult[10:7] is length, leftResult[6:0] is code
            reg [3:0] newLen;
            reg [6:0] newCode;
            newLen  = leftResult[10:7] + 1;
            newCode = (leftResult[6:0] << 1);  // add 0 in LSB
            dfs = {1'b1, newLen, newCode};
        end
        else begin
            // try right subtree => prepend bit '1'
            rightResult = dfs(right[currentNode], currentDepth+1);
            if (rightResult[11]) begin
            // found in right subtree
            reg [3:0] newLen;
            reg [6:0] newCode;
            newLen  = rightResult[10:7] + 1;
            newCode = (rightResult[6:0] << 1) | 1'b1;
            dfs = {1'b1, newLen, newCode};
            end
            else begin
            // not found in either child
            dfs = {1'b0, 4'd0, 7'b0};
            end
        end
    end
end
endfunction

// We now define a small function that, given a leaf symbol s (0..4),
// searches from 'root' down to that leaf and returns a 4-bit code
// (left=0, right=1). We do a depth-first search.  We also want to left-pad
// to 4 bits if the code is shorter than 4 bits.  If we never find the symbol
// (should not happen), we return 4'b0000.
function [3:0] getCode4bit;
   input [2:0]  leafSym;  // 0..4
   input [3:0]  root;     // typically 8 after building the tree

   reg [11:0] result;
   reg  found;
   reg [3:0] length;
   reg [6:0] codeLSBs;
   reg [3:0] code4;

begin
   result = dfs(root, 4'd0);
   found      = result[11];
   length     = result[10:7];
   codeLSBs   = result[6:0];   // code is in LSB side, length bits used

   // If not found or length=0 => code = 0
   if (!found || length==0) begin
       getCode4bit = 4'b0000;
   end
   else if (length <= 4) begin
       // The "rightmost length bits" of codeLSBs hold the code, from LSB up.
       // We want to left-pad to 4 bits. So if length=3 and codeLSBs=011 for example,
       // we want 4'b0011.
       // Let's just mask out the bits, then shift them into the low side,
       // then left-pad with zeros.
       reg [3:0] temp;
       temp = codeLSBs[3:0]; // take the lowest 4 bits
       // but we only use 'length' bits from there. We'll just shift them left 
       // so that they line up at the right edge.
       // Actually, codeLSBs is already in the correct order (lowest bit is the first branch from root).
       // So if length=3 => bits used are temp[2:0]. We'll do:
       temp = temp & ((1 << length) - 1);
       // Now place it in the rightmost 'length' bits of a 4-bit code.
       // That means we do no shift. It's already in LSB side. We only need to ensure the upper bits are 0.
       getCode4bit = temp;
   end
   else begin
       // If length > 4, we just truncate the least significant 4 bits (or handle error).
       // Typically with 5 symbols, max length is 4, but just in case:
       getCode4bit = codeLSBs[3:0];
   end
end
endfunction

//////////////////////////////////////////////
// The main combinational logic
//////////////////////////////////////////////
always @* begin : COMBINATIONAL_HUFFMAN
    // 1) Extract input frequencies
    // symbol_freq = { e[4:0], d[4:0], c[4:0], b[4:0], a[4:0] } from MSB to LSB
    // i.e. a_freq = symbol_freq[4:0], b_freq = [9:5], etc.
    reg [4:0] fa, fb, fc, fd, fe;
    // fa = symbol_freq[ 4: 0];
    // fb = symbol_freq[ 9: 5];
    // fc = symbol_freq[14:10];
    // fd = symbol_freq[19:15];
    // fe = symbol_freq[24:20];
    fa = symbol_freq[24:20];
    fb = symbol_freq[19:15];
    fc = symbol_freq[14:10];
    fd = symbol_freq[ 9: 5];
    fe = symbol_freq[ 4: 0];

    // 2) Initialize all 9 nodes
    for (i=0; i<9; i=i+1) begin
        freq[i]   = 8'd0;
        left[i]   = 4'hF;
        right[i]  = 4'hF;
        symbol[i] = 3'd7;  // 7 => internal
        active[i] = 1'b0;
    end

    // Leaves: node0..4 => a..e
    freq[0]   = fa;
    symbol[0] = 3'd0;  // 'a'
    active[0] = 1'b1;

    freq[1]   = fb;
    symbol[1] = 3'd1;  // 'b'
    active[1] = 1'b1;

    freq[2]   = fc;
    symbol[2] = 3'd2;  // 'c'
    active[2] = 1'b1;

    freq[3]   = fd;
    symbol[3] = 3'd3;  // 'd'
    active[3] = 1'b1;

    freq[4]   = fe;
    symbol[4] = 3'd4;  // 'e'
    active[4] = 1'b1;

    // internal nodes: 5..8, freq=0, symbol=7, not active initially

    // We'll do 4 merges, each time creating a new node #nextN
    reg [3:0] nextN;
    nextN = 5;

    integer step;
    for (step=0; step<4; step=step+1) begin
        // find two min among active
        reg [3:0] m1, m2;
        findTwoMin(m1, m2);
        // create new node nextN
        // put the smaller in left, the bigger in right
        if (lessOrEqual(m1, m2)) begin
            left[nextN]  = m1;
            right[nextN] = m2;
        end
        else begin
            left[nextN]  = m2;
            right[nextN] = m1;
        end

        freq[nextN]   = freq[m1] + freq[m2];
        symbol[nextN] = 3'd7; // internal
        active[m1]    = 1'b0;
        active[m2]    = 1'b0;
        active[nextN] = 1'b1;

        nextN = nextN + 1; // increment for next internal node
    end

    // Now the only active node should be node 8 => the root
    // 3) Retrieve the 4-bit code for each leaf
    reg [3:0] code_a, code_b, code_c, code_d, code_e;
    code_a = getCode4bit(3'd0, 8); // symbol=0 => 'a'
    code_b = getCode4bit(3'd1, 8); // symbol=1 => 'b'
    code_c = getCode4bit(3'd2, 8); // 'c'
    code_d = getCode4bit(3'd3, 8); // 'd'
    code_e = getCode4bit(3'd4, 8); // 'e'

    // 4) Concatenate them into 20 bits: a in [3:0], b in [7:4], c in [11:8], d in [15:12], e in [19:16]
    // out_encoded = {code_e, code_d, code_c, code_b, code_a};
    out_encoded = {code_a, code_b, code_c, code_d, code_e};
end

endmodule