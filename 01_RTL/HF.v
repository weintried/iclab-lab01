module HF(
    input [24:0] symbol_freq,
    output [19:0] out_encoded
);

    // Extract frequencies for each symbol
    wire [4:0] freq_a = symbol_freq[24:20];
    wire [4:0] freq_b = symbol_freq[19:15];
    wire [4:0] freq_c = symbol_freq[14:10];
    wire [4:0] freq_d = symbol_freq[9:5];
    wire [4:0] freq_e = symbol_freq[4:0];

    // Declare wires for nodes of the Huffman tree
    // We'll have 5 original symbols and 4 merged nodes
    // Extended to 8 bits to prevent overflow when adding frequencies
    // wire [7:0] freq_node6, freq_node7, freq_node8, freq_node9;       # FIXME: freq_node9 is not used
    wire [7:0] freq_node6, freq_node7, freq_node8;
    wire [3:0] code_a, code_b, code_c, code_d, code_e;
    wire [3:0] len_a, len_b, len_c, len_d, len_e;

    // Wires for node structure (for tracking the tree)
    wire [8:0] node6_children, node7_children, node8_children, node9_children;
    
    // Wires for tracking which nodes exist in each step
    wire [8:0] available_nodes_step1;
    wire [8:0] available_nodes_step2;
    wire [8:0] available_nodes_step3;
    wire [8:0] available_nodes_step4;
    
    // Initial available nodes (only the 5 original symbols)
    assign available_nodes_step1 = 9'b000011111;

    // Step 1: Find the two nodes with smallest frequencies among original symbols
    wire [8:0] smallest_nodes_step1;
    wire [4:0] smallest_freq_step1, second_smallest_freq_step1;
    wire [3:0] smallest_idx_step1, second_smallest_idx_step1;
    
    // Compare frequencies with tie-breaking rules
    // For original symbols with same frequency, order alphabetically (a-e)
    wire a_lt_b = (freq_a < freq_b) || (freq_a == freq_b && 1'b1);
    wire a_lt_c = (freq_a < freq_c) || (freq_a == freq_c && 1'b1);
    wire a_lt_d = (freq_a < freq_d) || (freq_a == freq_d && 1'b1);
    wire a_lt_e = (freq_a < freq_e) || (freq_a == freq_e && 1'b1);
    
    wire b_lt_c = (freq_b < freq_c) || (freq_b == freq_c && 1'b1);
    wire b_lt_d = (freq_b < freq_d) || (freq_b == freq_d && 1'b1);
    wire b_lt_e = (freq_b < freq_e) || (freq_b == freq_e && 1'b1);
    
    wire c_lt_d = (freq_c < freq_d) || (freq_c == freq_d && 1'b1);
    wire c_lt_e = (freq_c < freq_e) || (freq_c == freq_e && 1'b1);
    
    wire d_lt_e = (freq_d < freq_e) || (freq_d == freq_e && 1'b1);
    
    // Count how many other symbols each symbol is less than
    wire [2:0] a_rank = a_lt_b + a_lt_c + a_lt_d + a_lt_e;
    wire [2:0] b_rank = b_lt_c + b_lt_d + b_lt_e + !a_lt_b;
    wire [2:0] c_rank = c_lt_d + c_lt_e + !a_lt_c + !b_lt_c;
    wire [2:0] d_rank = d_lt_e + !a_lt_d + !b_lt_d + !c_lt_d;
    wire [2:0] e_rank = !a_lt_e + !b_lt_e + !c_lt_e + !d_lt_e;
    
    // Find the two smallest frequencies in step 1
    assign smallest_idx_step1 = (a_rank == 4) ? 4'd0 :
                               (b_rank == 4) ? 4'd1 :
                               (c_rank == 4) ? 4'd2 :
                               (d_rank == 4) ? 4'd3 : 4'd4;
                               
    assign second_smallest_idx_step1 = (a_rank == 3) ? 4'd0 :
                                      (b_rank == 3) ? 4'd1 :
                                      (c_rank == 3) ? 4'd2 :
                                      (d_rank == 3) ? 4'd3 : 4'd4;
    
    assign smallest_freq_step1 = (smallest_idx_step1 == 4'd0) ? freq_a :
                                (smallest_idx_step1 == 4'd1) ? freq_b :
                                (smallest_idx_step1 == 4'd2) ? freq_c :
                                (smallest_idx_step1 == 4'd3) ? freq_d : freq_e;
                                
    assign second_smallest_freq_step1 = (second_smallest_idx_step1 == 4'd0) ? freq_a :
                                       (second_smallest_idx_step1 == 4'd1) ? freq_b :
                                       (second_smallest_idx_step1 == 4'd2) ? freq_c :
                                       (second_smallest_idx_step1 == 4'd3) ? freq_d : freq_e;
    
    // Track which nodes were selected in step 1
    assign smallest_nodes_step1[0] = (smallest_idx_step1 == 4'd0) || (second_smallest_idx_step1 == 4'd0);
    assign smallest_nodes_step1[1] = (smallest_idx_step1 == 4'd1) || (second_smallest_idx_step1 == 4'd1);
    assign smallest_nodes_step1[2] = (smallest_idx_step1 == 4'd2) || (second_smallest_idx_step1 == 4'd2);
    assign smallest_nodes_step1[3] = (smallest_idx_step1 == 4'd3) || (second_smallest_idx_step1 == 4'd3);
    assign smallest_nodes_step1[4] = (smallest_idx_step1 == 4'd4) || (second_smallest_idx_step1 == 4'd4);
    assign smallest_nodes_step1[8:5] = 4'b0000;  // No merged nodes available yet
    
    // Merge the two smallest nodes to create node 6 (with proper bit extension)
    assign freq_node6 = {3'b000, smallest_freq_step1} + {3'b000, second_smallest_freq_step1};
    
    // Store the children of node 6
    assign node6_children = smallest_nodes_step1;
    
    // Update available nodes for step 2
    assign available_nodes_step2 = (available_nodes_step1 & ~smallest_nodes_step1) | 9'b000100000;
    
    // Step 2: Find the two smallest frequencies among remaining nodes
    wire [8:0] smallest_nodes_step2;
    wire [7:0] smallest_freq_step2, second_smallest_freq_step2;
    wire [3:0] smallest_idx_step2, second_smallest_idx_step2;
    
    // Compare node 6 with remaining original nodes (with proper bit extension)
    // Merged nodes take precedence over original symbols with the same frequency
    wire node6_lt_a = (freq_node6 < {3'b000, freq_a}) || (freq_node6 == {3'b000, freq_a} && 1'b1);
    wire node6_lt_b = (freq_node6 < {3'b000, freq_b}) || (freq_node6 == {3'b000, freq_b} && 1'b1);
    wire node6_lt_c = (freq_node6 < {3'b000, freq_c}) || (freq_node6 == {3'b000, freq_c} && 1'b1);
    wire node6_lt_d = (freq_node6 < {3'b000, freq_d}) || (freq_node6 == {3'b000, freq_d} && 1'b1);
    wire node6_lt_e = (freq_node6 < {3'b000, freq_e}) || (freq_node6 == {3'b000, freq_e} && 1'b1);
    
    // Helper function to check if a node is available in step 2
    wire a_avail_step2 = available_nodes_step2[0];
    wire b_avail_step2 = available_nodes_step2[1];
    wire c_avail_step2 = available_nodes_step2[2];
    wire d_avail_step2 = available_nodes_step2[3];
    wire e_avail_step2 = available_nodes_step2[4];
    wire node6_avail_step2 = available_nodes_step2[5];
    
    // Calculate rankings for step 2
    wire [2:0] a_rank_step2 = a_avail_step2 ? (a_lt_b & b_avail_step2) + (a_lt_c & c_avail_step2) + 
                             (a_lt_d & d_avail_step2) + (a_lt_e & e_avail_step2) + 
                             (!node6_lt_a & node6_avail_step2) : 3'b111;
                             
    wire [2:0] b_rank_step2 = b_avail_step2 ? (b_lt_c & c_avail_step2) + (b_lt_d & d_avail_step2) + 
                             (b_lt_e & e_avail_step2) + (!a_lt_b & a_avail_step2) + 
                             (!node6_lt_b & node6_avail_step2) : 3'b111;
                             
    wire [2:0] c_rank_step2 = c_avail_step2 ? (c_lt_d & d_avail_step2) + (c_lt_e & e_avail_step2) + 
                             (!a_lt_c & a_avail_step2) + (!b_lt_c & b_avail_step2) + 
                             (!node6_lt_c & node6_avail_step2) : 3'b111;
                             
    wire [2:0] d_rank_step2 = d_avail_step2 ? (d_lt_e & e_avail_step2) + (!a_lt_d & a_avail_step2) + 
                             (!b_lt_d & b_avail_step2) + (!c_lt_d & c_avail_step2) + 
                             (!node6_lt_d & node6_avail_step2) : 3'b111;
                             
    wire [2:0] e_rank_step2 = e_avail_step2 ? (!a_lt_e & a_avail_step2) + (!b_lt_e & b_avail_step2) + 
                             (!c_lt_e & c_avail_step2) + (!d_lt_e & d_avail_step2) + 
                             (!node6_lt_e & node6_avail_step2) : 3'b111;
                             
    wire [2:0] node6_rank_step2 = node6_avail_step2 ? (node6_lt_a & a_avail_step2) + 
                                 (node6_lt_b & b_avail_step2) + (node6_lt_c & c_avail_step2) + 
                                 (node6_lt_d & d_avail_step2) + (node6_lt_e & e_avail_step2) : 3'b111;
    
    // Find the two smallest frequencies in step 2
    assign smallest_idx_step2 = (a_rank_step2 == 3) ? 4'd0 :
                               (b_rank_step2 == 3) ? 4'd1 :
                               (c_rank_step2 == 3) ? 4'd2 :
                               (d_rank_step2 == 3) ? 4'd3 :
                               (e_rank_step2 == 3) ? 4'd4 : 4'd5;

    assign second_smallest_idx_step2 = (a_rank_step2 == 2) ? 4'd0 :
                                      (b_rank_step2 == 2) ? 4'd1 :
                                      (c_rank_step2 == 2) ? 4'd2 :
                                      (d_rank_step2 == 2) ? 4'd3 :
                                      (e_rank_step2 == 2) ? 4'd4 : 4'd5;
    
    // Get the frequencies for the selected indices with proper bit width
    assign smallest_freq_step2 = (smallest_idx_step2 == 4'd0) ? {3'b000, freq_a} :
                                (smallest_idx_step2 == 4'd1) ? {3'b000, freq_b} :
                                (smallest_idx_step2 == 4'd2) ? {3'b000, freq_c} :
                                (smallest_idx_step2 == 4'd3) ? {3'b000, freq_d} :
                                (smallest_idx_step2 == 4'd4) ? {3'b000, freq_e} : freq_node6;
                                
    assign second_smallest_freq_step2 = (second_smallest_idx_step2 == 4'd0) ? {3'b000, freq_a} :
                                       (second_smallest_idx_step2 == 4'd1) ? {3'b000, freq_b} :
                                       (second_smallest_idx_step2 == 4'd2) ? {3'b000, freq_c} :
                                       (second_smallest_idx_step2 == 4'd3) ? {3'b000, freq_d} :
                                       (second_smallest_idx_step2 == 4'd4) ? {3'b000, freq_e} : freq_node6;
    
    // Track which nodes were selected in step 2
    assign smallest_nodes_step2[0] = (smallest_idx_step2 == 4'd0) || (second_smallest_idx_step2 == 4'd0);
    assign smallest_nodes_step2[1] = (smallest_idx_step2 == 4'd1) || (second_smallest_idx_step2 == 4'd1);
    assign smallest_nodes_step2[2] = (smallest_idx_step2 == 4'd2) || (second_smallest_idx_step2 == 4'd2);
    assign smallest_nodes_step2[3] = (smallest_idx_step2 == 4'd3) || (second_smallest_idx_step2 == 4'd3);
    assign smallest_nodes_step2[4] = (smallest_idx_step2 == 4'd4) || (second_smallest_idx_step2 == 4'd4);
    assign smallest_nodes_step2[5] = (smallest_idx_step2 == 4'd5) || (second_smallest_idx_step2 == 4'd5);
    assign smallest_nodes_step2[8:6] = 3'b000;
    
    // Merge the two smallest nodes to create node 7
    assign freq_node7 = smallest_freq_step2 + second_smallest_freq_step2;
    
    // Store the children of node 7
    assign node7_children = smallest_nodes_step2;
    
    // Update available nodes for step 3
    assign available_nodes_step3 = (available_nodes_step2 & ~smallest_nodes_step2) | 9'b001000000;
    
    // Step 3: Find the two smallest frequencies among remaining nodes
    wire [8:0] smallest_nodes_step3;
    wire [7:0] smallest_freq_step3, second_smallest_freq_step3;
    wire [3:0] smallest_idx_step3, second_smallest_idx_step3;
    
    // Compare node 7 with remaining nodes (with proper bit extension)
    wire node7_lt_a = (freq_node7 < {3'b000, freq_a}) || (freq_node7 == {3'b000, freq_a} && 1'b1);
    wire node7_lt_b = (freq_node7 < {3'b000, freq_b}) || (freq_node7 == {3'b000, freq_b} && 1'b1);
    wire node7_lt_c = (freq_node7 < {3'b000, freq_c}) || (freq_node7 == {3'b000, freq_c} && 1'b1);
    wire node7_lt_d = (freq_node7 < {3'b000, freq_d}) || (freq_node7 == {3'b000, freq_d} && 1'b1);
    wire node7_lt_e = (freq_node7 < {3'b000, freq_e}) || (freq_node7 == {3'b000, freq_e} && 1'b1);
    wire node7_lt_node6 = (freq_node7 < freq_node6) || (freq_node7 == freq_node6 && 1'b1);
    
    // Helper function to check if a node is available in step 3
    wire a_avail_step3 = available_nodes_step3[0];
    wire b_avail_step3 = available_nodes_step3[1];
    wire c_avail_step3 = available_nodes_step3[2];
    wire d_avail_step3 = available_nodes_step3[3];
    wire e_avail_step3 = available_nodes_step3[4];
    wire node6_avail_step3 = available_nodes_step3[5];
    wire node7_avail_step3 = available_nodes_step3[6];
    
    // Calculate rankings for step 3
    wire [2:0] a_rank_step3 = a_avail_step3 ? (a_lt_b & b_avail_step3) + (a_lt_c & c_avail_step3) + 
                             (a_lt_d & d_avail_step3) + (a_lt_e & e_avail_step3) + 
                             (!node6_lt_a & node6_avail_step3) + (!node7_lt_a & node7_avail_step3) : 3'b111;
                             
    wire [2:0] b_rank_step3 = b_avail_step3 ? (b_lt_c & c_avail_step3) + (b_lt_d & d_avail_step3) + 
                             (b_lt_e & e_avail_step3) + (!a_lt_b & a_avail_step3) + 
                             (!node6_lt_b & node6_avail_step3) + (!node7_lt_b & node7_avail_step3) : 3'b111;
                             
    wire [2:0] c_rank_step3 = c_avail_step3 ? (c_lt_d & d_avail_step3) + (c_lt_e & e_avail_step3) + 
                             (!a_lt_c & a_avail_step3) + (!b_lt_c & b_avail_step3) + 
                             (!node6_lt_c & node6_avail_step3) + (!node7_lt_c & node7_avail_step3) : 3'b111;
                             
    wire [2:0] d_rank_step3 = d_avail_step3 ? (d_lt_e & e_avail_step3) + (!a_lt_d & a_avail_step3) + 
                             (!b_lt_d & b_avail_step3) + (!c_lt_d & c_avail_step3) + 
                             (!node6_lt_d & node6_avail_step3) + (!node7_lt_d & node7_avail_step3) : 3'b111;
                             
    wire [2:0] e_rank_step3 = e_avail_step3 ? (!a_lt_e & a_avail_step3) + (!b_lt_e & b_avail_step3) + 
                             (!c_lt_e & c_avail_step3) + (!d_lt_e & d_avail_step3) + 
                             (!node6_lt_e & node6_avail_step3) + (!node7_lt_e & node7_avail_step3) : 3'b111;
                             
    wire [2:0] node6_rank_step3 = node6_avail_step3 ? (node6_lt_a & a_avail_step3) + 
                                 (node6_lt_b & b_avail_step3) + (node6_lt_c & c_avail_step3) + 
                                 (node6_lt_d & d_avail_step3) + (node6_lt_e & e_avail_step3) + 
                                 (!node7_lt_node6 & node7_avail_step3) : 3'b111;
                                 
    wire [2:0] node7_rank_step3 = node7_avail_step3 ? (node7_lt_a & a_avail_step3) + 
                                 (node7_lt_b & b_avail_step3) + (node7_lt_c & c_avail_step3) + 
                                 (node7_lt_d & d_avail_step3) + (node7_lt_e & e_avail_step3) + 
                                 (node7_lt_node6 & node6_avail_step3) : 3'b111;
    
    // Find the two smallest frequencies in step 3
    assign smallest_idx_step3 = (a_rank_step3 == 2) ? 4'd0 :
                               (b_rank_step3 == 2) ? 4'd1 :
                               (c_rank_step3 == 2) ? 4'd2 :
                               (d_rank_step3 == 2) ? 4'd3 :
                               (e_rank_step3 == 2) ? 4'd4 :
                               (node6_rank_step3 == 2) ? 4'd5 : 4'd6;
                               
    assign second_smallest_idx_step3 = (a_rank_step3 == 1) ? 4'd0 :
                                      (b_rank_step3 == 1) ? 4'd1 :
                                      (c_rank_step3 == 1) ? 4'd2 :
                                      (d_rank_step3 == 1) ? 4'd3 :
                                      (e_rank_step3 == 1) ? 4'd4 :
                                      (node6_rank_step3 == 1) ? 4'd5 : 4'd6;
    
    // Get the frequencies for the selected indices with proper bit width
    assign smallest_freq_step3 = (smallest_idx_step3 == 4'd0) ? {3'b000, freq_a} :
                                (smallest_idx_step3 == 4'd1) ? {3'b000, freq_b} :
                                (smallest_idx_step3 == 4'd2) ? {3'b000, freq_c} :
                                (smallest_idx_step3 == 4'd3) ? {3'b000, freq_d} :
                                (smallest_idx_step3 == 4'd4) ? {3'b000, freq_e} :
                                (smallest_idx_step3 == 4'd5) ? freq_node6 : freq_node7;
                                
    assign second_smallest_freq_step3 = (second_smallest_idx_step3 == 4'd0) ? {3'b000, freq_a} :
                                       (second_smallest_idx_step3 == 4'd1) ? {3'b000, freq_b} :
                                       (second_smallest_idx_step3 == 4'd2) ? {3'b000, freq_c} :
                                       (second_smallest_idx_step3 == 4'd3) ? {3'b000, freq_d} :
                                       (second_smallest_idx_step3 == 4'd4) ? {3'b000, freq_e} :
                                       (second_smallest_idx_step3 == 4'd5) ? freq_node6 : freq_node7;
    
    // Track which nodes were selected in step 3
    assign smallest_nodes_step3[0] = (smallest_idx_step3 == 4'd0) || (second_smallest_idx_step3 == 4'd0);
    assign smallest_nodes_step3[1] = (smallest_idx_step3 == 4'd1) || (second_smallest_idx_step3 == 4'd1);
    assign smallest_nodes_step3[2] = (smallest_idx_step3 == 4'd2) || (second_smallest_idx_step3 == 4'd2);
    assign smallest_nodes_step3[3] = (smallest_idx_step3 == 4'd3) || (second_smallest_idx_step3 == 4'd3);
    assign smallest_nodes_step3[4] = (smallest_idx_step3 == 4'd4) || (second_smallest_idx_step3 == 4'd4);
    assign smallest_nodes_step3[5] = (smallest_idx_step3 == 4'd5) || (second_smallest_idx_step3 == 4'd5);
    assign smallest_nodes_step3[6] = (smallest_idx_step3 == 4'd6) || (second_smallest_idx_step3 == 4'd6);
    assign smallest_nodes_step3[8:7] = 2'b00;
    
    // Merge the two smallest nodes to create node 8
    assign freq_node8 = smallest_freq_step3 + second_smallest_freq_step3;
    
    // Store the children of node 8
    assign node8_children = smallest_nodes_step3;
    
    // Update available nodes for step 4
    assign available_nodes_step4 = (available_nodes_step3 & ~smallest_nodes_step3) | 9'b010000000;
    
    // Step 4: The final two nodes will be merged to form the root
    wire [8:0] smallest_nodes_step4;
    wire [7:0] smallest_freq_step4, second_smallest_freq_step4;
    wire [3:0] smallest_idx_step4, second_smallest_idx_step4;
    
    // Compare node 8 with remaining nodes (with proper bit extension)
    wire node8_lt_a = (freq_node8 < {3'b000, freq_a}) || (freq_node8 == {3'b000, freq_a} && 1'b1);
    wire node8_lt_b = (freq_node8 < {3'b000, freq_b}) || (freq_node8 == {3'b000, freq_b} && 1'b1);
    wire node8_lt_c = (freq_node8 < {3'b000, freq_c}) || (freq_node8 == {3'b000, freq_c} && 1'b1);
    wire node8_lt_d = (freq_node8 < {3'b000, freq_d}) || (freq_node8 == {3'b000, freq_d} && 1'b1);
    wire node8_lt_e = (freq_node8 < {3'b000, freq_e}) || (freq_node8 == {3'b000, freq_e} && 1'b1);
    wire node8_lt_node6 = (freq_node8 < freq_node6) || (freq_node8 == freq_node6 && 1'b1);
    wire node8_lt_node7 = (freq_node8 < freq_node7) || (freq_node8 == freq_node7 && 1'b1);

    // Helper function to check if a node is available in step 4
    wire a_avail_step4 = available_nodes_step4[0];
    wire b_avail_step4 = available_nodes_step4[1];
    wire c_avail_step4 = available_nodes_step4[2];
    wire d_avail_step4 = available_nodes_step4[3];
    wire e_avail_step4 = available_nodes_step4[4];
    wire node6_avail_step4 = available_nodes_step4[5];
    wire node7_avail_step4 = available_nodes_step4[6];
    wire node8_avail_step4 = available_nodes_step4[7];

    // Calculate rankings for step 4
    wire [2:0] a_rank_step4 = a_avail_step4 ? (a_lt_b & b_avail_step4) + (a_lt_c & c_avail_step4) + 
                             (a_lt_d & d_avail_step4) + (a_lt_e & e_avail_step4) + 
                             (!node6_lt_a & node6_avail_step4) + (!node7_lt_a & node7_avail_step4) + 
                             (!node8_lt_a & node8_avail_step4) : 3'b111;
    wire [2:0] b_rank_step4 = b_avail_step4 ? (b_lt_c & c_avail_step4) + (b_lt_d & d_avail_step4) + 
                             (b_lt_e & e_avail_step4) + (!a_lt_b & a_avail_step4) + 
                             (!node6_lt_b & node6_avail_step4) + (!node7_lt_b & node7_avail_step4) + 
                             (!node8_lt_b & node8_avail_step4) : 3'b111;
    wire [2:0] c_rank_step4 = c_avail_step4 ? (c_lt_d & d_avail_step4) + (c_lt_e & e_avail_step4) + 
                             (!a_lt_c & a_avail_step4) + (!b_lt_c & b_avail_step4) + 
                             (!node6_lt_c & node6_avail_step4) + (!node7_lt_c & node7_avail_step4) + 
                             (!node8_lt_c & node8_avail_step4) : 3'b111;
    wire [2:0] d_rank_step4 = d_avail_step4 ? (d_lt_e & e_avail_step4) + (!a_lt_d & a_avail_step4) + 
                             (!b_lt_d & b_avail_step4) + (!c_lt_d & c_avail_step4) + 
                             (!node6_lt_d & node6_avail_step4) + (!node7_lt_d & node7_avail_step4) + 
                             (!node8_lt_d & node8_avail_step4) : 3'b111;
    wire [2:0] e_rank_step4 = e_avail_step4 ? (!a_lt_e & a_avail_step4) + (!b_lt_e & b_avail_step4) + 
                             (!c_lt_e & c_avail_step4) + (!d_lt_e & d_avail_step4) + 
                             (!node6_lt_e & node6_avail_step4) + (!node7_lt_e & node7_avail_step4) + 
                             (!node8_lt_e & node8_avail_step4) : 3'b111;
    wire [2:0] node6_rank_step4 = node6_avail_step4 ? (node6_lt_a & a_avail_step4) + 
                                 (node6_lt_b & b_avail_step4) + (node6_lt_c & c_avail_step4) + 
                                 (node6_lt_d & d_avail_step4) + (node6_lt_e & e_avail_step4) + 
                                 (!node7_lt_node6 & node7_avail_step4) + (!node8_lt_node6 & node8_avail_step4) : 3'b111;
    wire [2:0] node7_rank_step4 = node7_avail_step4 ? (node7_lt_a & a_avail_step4) +
                                 (node7_lt_b & b_avail_step4) + (node7_lt_c & c_avail_step4) +
                                 (node7_lt_d & d_avail_step4) + (node7_lt_e & e_avail_step4) +
                                 (node7_lt_node6 & node6_avail_step4) + (!node8_lt_node7 & node8_avail_step4) : 3'b111;
    wire [2:0] node8_rank_step4 = node8_avail_step4 ? (node8_lt_a & a_avail_step4) +
                                 (node8_lt_b & b_avail_step4) + (node8_lt_c & c_avail_step4) +
                                 (node8_lt_d & d_avail_step4) + (node8_lt_e & e_avail_step4) +
                                 (node8_lt_node6 & node6_avail_step4) + (node8_lt_node7 & node7_avail_step4) : 3'b111;

    // Find the two smallest frequencies in step 4
    assign smallest_idx_step4 = (a_rank_step4 == 1) ? 4'd0 :
                               (b_rank_step4 == 1) ? 4'd1 :
                               (c_rank_step4 == 1) ? 4'd2 :
                               (d_rank_step4 == 1) ? 4'd3 :
                               (e_rank_step4 == 1) ? 4'd4 :
                               (node6_rank_step4 == 1) ? 4'd5 :
                               (node7_rank_step4 == 1) ? 4'd6 : 4'd7;

    assign second_smallest_idx_step4 = (a_rank_step4 == 0) ? 4'd0 :
                                      (b_rank_step4 == 0) ? 4'd1 :
                                      (c_rank_step4 == 0) ? 4'd2 :
                                      (d_rank_step4 == 0) ? 4'd3 :
                                      (e_rank_step4 == 0) ? 4'd4 :
                                      (node6_rank_step4 == 0) ? 4'd5 :
                                      (node7_rank_step4 == 0) ? 4'd6 : 4'd7;

    // Get the frequencies for the selected indices with proper bit width
    assign smallest_freq_step4 = (smallest_idx_step4 == 4'd0) ? {3'b000, freq_a} :
                                (smallest_idx_step4 == 4'd1) ? {3'b000, freq_b} :
                                (smallest_idx_step4 == 4'd2) ? {3'b000, freq_c} :
                                (smallest_idx_step4 == 4'd3) ? {3'b000, freq_d} :
                                (smallest_idx_step4 == 4'd4) ? {3'b000, freq_e} :
                                (smallest_idx_step4 == 4'd5) ? freq_node6 :
                                (smallest_idx_step4 == 4'd6) ? freq_node7 : freq_node8;

    assign second_smallest_freq_step4 = (second_smallest_idx_step4 == 4'd0) ? {3'b000, freq_a} :
                                       (second_smallest_idx_step4 == 4'd1) ? {3'b000, freq_b} :
                                       (second_smallest_idx_step4 == 4'd2) ? {3'b000, freq_c} :
                                       (second_smallest_idx_step4 == 4'd3) ? {3'b000, freq_d} :
                                       (second_smallest_idx_step4 == 4'd4) ? {3'b000, freq_e} :
                                       (second_smallest_idx_step4 == 4'd5) ? freq_node6 :
                                       (second_smallest_idx_step4 == 4'd6) ? freq_node7 : freq_node8;

    // Track which nodes were selected in step 4
    assign smallest_nodes_step4[0] = (smallest_idx_step4 == 4'd0) || (second_smallest_idx_step4 == 4'd0);
    assign smallest_nodes_step4[1] = (smallest_idx_step4 == 4'd1) || (second_smallest_idx_step4 == 4'd1);
    assign smallest_nodes_step4[2] = (smallest_idx_step4 == 4'd2) || (second_smallest_idx_step4 == 4'd2);
    assign smallest_nodes_step4[3] = (smallest_idx_step4 == 4'd3) || (second_smallest_idx_step4 == 4'd3);
    assign smallest_nodes_step4[4] = (smallest_idx_step4 == 4'd4) || (second_smallest_idx_step4 == 4'd4);
    assign smallest_nodes_step4[5] = (smallest_idx_step4 == 4'd5) || (second_smallest_idx_step4 == 4'd5);
    assign smallest_nodes_step4[6] = (smallest_idx_step4 == 4'd6) || (second_smallest_idx_step4 == 4'd6);
    assign smallest_nodes_step4[7] = (smallest_idx_step4 == 4'd7) || (second_smallest_idx_step4 == 4'd7);
    assign smallest_nodes_step4[8] = 1'b0;

    // At this point, there should be exactly two nodes available
    // Since we've been merging pairs of nodes, the only ones left are the last two
    wire [7:0] node9_freq = freq_node8 + 
                           (available_nodes_step4[0] ? {3'b000, freq_a} : 8'b00000000) +
                           (available_nodes_step4[1] ? {3'b000, freq_b} : 8'b00000000) +
                           (available_nodes_step4[2] ? {3'b000, freq_c} : 8'b00000000) +
                           (available_nodes_step4[3] ? {3'b000, freq_d} : 8'b00000000) +
                           (available_nodes_step4[4] ? {3'b000, freq_e} : 8'b00000000) +
                           (available_nodes_step4[5] ? freq_node6 : 8'b00000000) +
                           (available_nodes_step4[6] ? freq_node7 : 8'b00000000);
    
    // Store the children of node 9 (root)
    assign node9_children = available_nodes_step4;
    
    // Now, traverse the tree to compute the codes for each symbol
    
    // FIXME: a bit weird here, check the commented code later
    // First, determine if each symbol is a left or right child of its parent
    // wire a_is_left_of_node6 = node6_children[0] && (smallest_idx_step1 == 0 || 
    //                          (second_smallest_idx_step1 == 0 && smallest_idx_step1 < second_smallest_idx_step1));
    // wire b_is_left_of_node6 = node6_children[1] && (smallest_idx_step1 == 1 || 
    //                          (second_smallest_idx_step1 == 1 && smallest_idx_step1 < second_smallest_idx_step1));
    // wire c_is_left_of_node6 = node6_children[2] && (smallest_idx_step1 == 2 || 
    //                          (second_smallest_idx_step1 == 2 && smallest_idx_step1 < second_smallest_idx_step1));
    // wire d_is_left_of_node6 = node6_children[3] && (smallest_idx_step1 == 3 || 
    //                          (second_smallest_idx_step1 == 3 && smallest_idx_step1 < second_smallest_idx_step1));
    // wire e_is_left_of_node6 = node6_children[4] && (smallest_idx_step1 == 4 || 
    //                          (second_smallest_idx_step1 == 4 && smallest_idx_step1 < second_smallest_idx_step1));
    wire a_is_left_of_node6 = node6_children[0] && smallest_idx_step1 == 0;
    wire b_is_left_of_node6 = node6_children[1] && smallest_idx_step1 == 1;
    wire c_is_left_of_node6 = node6_children[2] && smallest_idx_step1 == 2;
    wire d_is_left_of_node6 = node6_children[3] && smallest_idx_step1 == 3;
    wire e_is_left_of_node6 = node6_children[4] && smallest_idx_step1 == 4;
    
    // wire a_is_left_of_node7 = node7_children[0] && (smallest_idx_step2 == 0 || 
    //                          (second_smallest_idx_step2 == 0 && smallest_idx_step2 < second_smallest_idx_step2));
    // wire b_is_left_of_node7 = node7_children[1] && (smallest_idx_step2 == 1 || 
    //                          (second_smallest_idx_step2 == 1 && smallest_idx_step2 < second_smallest_idx_step2));
    // wire c_is_left_of_node7 = node7_children[2] && (smallest_idx_step2 == 2 || 
    //                          (second_smallest_idx_step2 == 2 && smallest_idx_step2 < second_smallest_idx_step2));
    // wire d_is_left_of_node7 = node7_children[3] && (smallest_idx_step2 == 3 || 
    //                          (second_smallest_idx_step2 == 3 && smallest_idx_step2 < second_smallest_idx_step2));
    // wire e_is_left_of_node7 = node7_children[4] && (smallest_idx_step2 == 4 || 
    //                          (second_smallest_idx_step2 == 4 && smallest_idx_step2 < second_smallest_idx_step2));
    // wire node6_is_left_of_node7 = node7_children[5] && (smallest_idx_step2 == 5 || 
    //                               (second_smallest_idx_step2 == 5 && smallest_idx_step2 < second_smallest_idx_step2));
    wire a_is_left_of_node7 = node7_children[0] && (smallest_idx_step2 == 0);
    wire b_is_left_of_node7 = node7_children[1] && (smallest_idx_step2 == 1);
    wire c_is_left_of_node7 = node7_children[2] && (smallest_idx_step2 == 2);
    wire d_is_left_of_node7 = node7_children[3] && (smallest_idx_step2 == 3);
    wire e_is_left_of_node7 = node7_children[4] && (smallest_idx_step2 == 4);
    wire node6_is_left_of_node7 = node7_children[5] && (smallest_idx_step2 == 5);
    
    // wire a_is_left_of_node8 = node8_children[0] && (smallest_idx_step3 == 0 || 
                            //  (second_smallest_idx_step3 == 0 && smallest_idx_step3 < second_smallest_idx_step3));
    // wire b_is_left_of_node8 = node8_children[1] && (smallest_idx_step3 == 1 || 
                            //  (second_smallest_idx_step3 == 1 && smallest_idx_step3 < second_smallest_idx_step3));
    // wire c_is_left_of_node8 = node8_children[2] && (smallest_idx_step3 == 2 || 
                            //  (second_smallest_idx_step3 == 2 && smallest_idx_step3 < second_smallest_idx_step3));
    // wire d_is_left_of_node8 = node8_children[3] && (smallest_idx_step3 == 3 || 
                            //  (second_smallest_idx_step3 == 3 && smallest_idx_step3 < second_smallest_idx_step3));
    // wire e_is_left_of_node8 = node8_children[4] && (smallest_idx_step3 == 4 || 
                            //  (second_smallest_idx_step3 == 4 && smallest_idx_step3 < second_smallest_idx_step3));
    // wire node6_is_left_of_node8 = node8_children[5] && (smallest_idx_step3 == 5 || 
                                //   (second_smallest_idx_step3 == 5 && smallest_idx_step3 < second_smallest_idx_step3));
    // wire node7_is_left_of_node8 = node8_children[6] && (smallest_idx_step3 == 6 || 
                                //   (second_smallest_idx_step3 == 6 && smallest_idx_step3 < second_smallest_idx_step3));
    wire a_is_left_of_node8 = node8_children[0] && (smallest_idx_step3 == 0);
    wire b_is_left_of_node8 = node8_children[1] && (smallest_idx_step3 == 1);
    wire c_is_left_of_node8 = node8_children[2] && (smallest_idx_step3 == 2);
    wire d_is_left_of_node8 = node8_children[3] && (smallest_idx_step3 == 3);
    wire e_is_left_of_node8 = node8_children[4] && (smallest_idx_step3 == 4);
    wire node6_is_left_of_node8 = node8_children[5] && (smallest_idx_step3 == 5);
    wire node7_is_left_of_node8 = node8_children[6] && (smallest_idx_step3 == 6);
    
    // FIXME: I don't know how to write the logic from this point on. PLS HELP
    wire node8_is_left_of_node9 = node9_children[7] && node9_children[8:0] != 9'b000000000;
    wire a_is_left_of_node9 = node9_children[0] && !node8_is_left_of_node9;
    wire b_is_left_of_node9 = node9_children[1] && !node8_is_left_of_node9;
    wire c_is_left_of_node9 = node9_children[2] && !node8_is_left_of_node9;
    wire d_is_left_of_node9 = node9_children[3] && !node8_is_left_of_node9;
    wire e_is_left_of_node9 = node9_children[4] && !node8_is_left_of_node9;
    wire node6_is_left_of_node9 = node9_children[5] && !node8_is_left_of_node9;
    wire node7_is_left_of_node9 = node9_children[6] && !node8_is_left_of_node9;
    
    // Compute the code and length for each symbol
    // Code is built by traversing the tree from the root to the symbol
    // 0 for left branch, 1 for right branch
    
    // Symbol 'a'
    assign len_a = (node6_children[0] ? 1'b1 : 1'b0) +
                  (node7_children[0] ? 1'b1 : 1'b0) +
                  (node8_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[0] ? 1'b1 : 1'b0) +
                  (node7_children[5] && node6_children[0] ? 1'b1 : 1'b0) +
                  (node8_children[5] && node6_children[0] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[0] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[5] && node6_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[5] && node6_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[5] && node6_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[5] && node6_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[0] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[5] && node6_children[0] ? 1'b1 : 1'b0);
                  
    wire a_bit0 = a_is_left_of_node6 || a_is_left_of_node7 || a_is_left_of_node8 || a_is_left_of_node9 ? 1'b0 : 1'b1;
    wire a_bit1 = (node6_children[0] && (node7_is_left_of_node8 || node7_is_left_of_node9)) ||
                 (node7_children[0] && node8_is_left_of_node9) ||
                 (a_is_left_of_node7 && node6_is_left_of_node8) ||
                 (a_is_left_of_node8 && !(node6_is_left_of_node7 && node7_is_left_of_node8)) ? 1'b0 : 1'b1;
    wire a_bit2 = (a_is_left_of_node6 && !(node7_children[5] && node8_is_left_of_node9) && !(node8_children[5])) ||
                 (a_is_left_of_node7 && !(node8_children[6])) ||
                 (a_is_left_of_node8 && !(node9_children[7])) ? 1'b0 : 1'b1;
    wire a_bit3 = a_is_left_of_node6 && node7_children[5] && node8_children[6] && node9_children[7] ? 1'b0 : 1'b1;
    
    assign code_a = (len_a == 4'd1) ? {3'b000, a_bit0} :
                   (len_a == 4'd2) ? {2'b00, a_bit0, a_bit1} :
                   (len_a == 4'd3) ? {1'b0, a_bit0, a_bit1, a_bit2} :
                   {a_bit0, a_bit1, a_bit2, a_bit3};
    
    // Symbol 'b' (similar logic as 'a')
    assign len_b = (node6_children[1] ? 1'b1 : 1'b0) +
                  (node7_children[1] ? 1'b1 : 1'b0) +
                  (node8_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[1] ? 1'b1 : 1'b0) +
                  (node7_children[5] && node6_children[1] ? 1'b1 : 1'b0) +
                  (node8_children[5] && node6_children[1] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[1] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[5] && node6_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[5] && node6_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[5] && node6_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[5] && node6_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[1] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[5] && node6_children[1] ? 1'b1 : 1'b0);
                  
    wire b_bit0 = b_is_left_of_node6 || b_is_left_of_node7 || b_is_left_of_node8 || b_is_left_of_node9 ? 1'b0 : 1'b1;
    wire b_bit1 = (node6_children[1] && (node7_is_left_of_node8 || node7_is_left_of_node9)) ||
                 (node7_children[1] && node8_is_left_of_node9) ||
                 (b_is_left_of_node7 && node6_is_left_of_node8) ||
                 (b_is_left_of_node8 && !(node6_is_left_of_node7 && node7_is_left_of_node8)) ? 1'b0 : 1'b1;
    wire b_bit2 = (b_is_left_of_node6 && !(node7_children[5] && node8_is_left_of_node9) && !(node8_children[5])) ||
                 (b_is_left_of_node7 && !(node8_children[6])) ||
                 (b_is_left_of_node8 && !(node9_children[7])) ? 1'b0 : 1'b1;
    wire b_bit3 = b_is_left_of_node6 && node7_children[5] && node8_children[6] && node9_children[7] ? 1'b0 : 1'b1;
    
    assign code_b = (len_b == 4'd1) ? {3'b000, b_bit0} :
                   (len_b == 4'd2) ? {2'b00, b_bit0, b_bit1} :
                   (len_b == 4'd3) ? {1'b0, b_bit0, b_bit1, b_bit2} :
                   {b_bit0, b_bit1, b_bit2, b_bit3};
    
    // Symbol 'c' (similar logic)
    assign len_c = (node6_children[2] ? 1'b1 : 1'b0) +
                  (node7_children[2] ? 1'b1 : 1'b0) +
                  (node8_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[2] ? 1'b1 : 1'b0) +
                  (node7_children[5] && node6_children[2] ? 1'b1 : 1'b0) +
                  (node8_children[5] && node6_children[2] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[2] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[5] && node6_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[5] && node6_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[5] && node6_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[5] && node6_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[2] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[5] && node6_children[2] ? 1'b1 : 1'b0);
                  
    wire c_bit0 = c_is_left_of_node6 || c_is_left_of_node7 || c_is_left_of_node8 || c_is_left_of_node9 ? 1'b0 : 1'b1;
    wire c_bit1 = (node6_children[2] && (node7_is_left_of_node8 || node7_is_left_of_node9)) ||
                 (node7_children[2] && node8_is_left_of_node9) ||
                 (c_is_left_of_node7 && node6_is_left_of_node8) ||
                 (c_is_left_of_node8 && !(node6_is_left_of_node7 && node7_is_left_of_node8)) ? 1'b0 : 1'b1;
    wire c_bit2 = (c_is_left_of_node6 && !(node7_children[5] && node8_is_left_of_node9) && !(node8_children[5])) ||
                 (c_is_left_of_node7 && !(node8_children[6])) ||
                 (c_is_left_of_node8 && !(node9_children[7])) ? 1'b0 : 1'b1;
    wire c_bit3 = c_is_left_of_node6 && node7_children[5] && node8_children[6] && node9_children[7] ? 1'b0 : 1'b1;
    
    assign code_c = (len_c == 4'd1) ? {3'b000, c_bit0} :
                   (len_c == 4'd2) ? {2'b00, c_bit0, c_bit1} :
                   (len_c == 4'd3) ? {1'b0, c_bit0, c_bit1, c_bit2} :
                   {c_bit0, c_bit1, c_bit2, c_bit3};
    
    // Symbol 'd' (similar logic)
    assign len_d = (node6_children[3] ? 1'b1 : 1'b0) +
                  (node7_children[3] ? 1'b1 : 1'b0) +
                  (node8_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[3] ? 1'b1 : 1'b0) +
                  (node7_children[5] && node6_children[3] ? 1'b1 : 1'b0) +
                  (node8_children[5] && node6_children[3] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[3] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[5] && node6_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[5] && node6_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[5] && node6_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[5] && node6_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[3] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[5] && node6_children[3] ? 1'b1 : 1'b0);
                  
    wire d_bit0 = d_is_left_of_node6 || d_is_left_of_node7 || d_is_left_of_node8 || d_is_left_of_node9 ? 1'b0 : 1'b1;
    wire d_bit1 = (node6_children[3] && (node7_is_left_of_node8 || node7_is_left_of_node9)) ||
                 (node7_children[3] && node8_is_left_of_node9) ||
                 (d_is_left_of_node7 && node6_is_left_of_node8) ||
                 (d_is_left_of_node8 && !(node6_is_left_of_node7 && node7_is_left_of_node8)) ? 1'b0 : 1'b1;
    wire d_bit2 = (d_is_left_of_node6 && !(node7_children[5] && node8_is_left_of_node9) && !(node8_children[5])) ||
                 (d_is_left_of_node7 && !(node8_children[6])) ||
                 (d_is_left_of_node8 && !(node9_children[7])) ? 1'b0 : 1'b1;
    wire d_bit3 = d_is_left_of_node6 && node7_children[5] && node8_children[6] && node9_children[7] ? 1'b0 : 1'b1;
    
    assign code_d = (len_d == 4'd1) ? {3'b000, d_bit0} :
                   (len_d == 4'd2) ? {2'b00, d_bit0, d_bit1} :
                   (len_d == 4'd3) ? {1'b0, d_bit0, d_bit1, d_bit2} :
                   {d_bit0, d_bit1, d_bit2, d_bit3};
    
    // Symbol 'e' (similar logic)
    assign len_e = (node6_children[4] ? 1'b1 : 1'b0) +
                  (node7_children[4] ? 1'b1 : 1'b0) +
                  (node8_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[4] ? 1'b1 : 1'b0) +
                  (node7_children[5] && node6_children[4] ? 1'b1 : 1'b0) +
                  (node8_children[5] && node6_children[4] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[4] ? 1'b1 : 1'b0) +
                  (node8_children[6] && node7_children[5] && node6_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[5] && node6_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[6] && node7_children[5] && node6_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[5] && node6_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[4] ? 1'b1 : 1'b0) +
                  (node9_children[7] && node8_children[6] && node7_children[5] && node6_children[4] ? 1'b1 : 1'b0);
                  
    wire e_bit0 = e_is_left_of_node6 || e_is_left_of_node7 || e_is_left_of_node8 || e_is_left_of_node9 ? 1'b0 : 1'b1;
    wire e_bit1 = (node6_children[4] && (node7_is_left_of_node8 || node7_is_left_of_node9)) ||
                 (node7_children[4] && node8_is_left_of_node9) ||
                 (e_is_left_of_node7 && node6_is_left_of_node8) ||
                 (e_is_left_of_node8 && !(node6_is_left_of_node7 && node7_is_left_of_node8)) ? 1'b0 : 1'b1;
    wire e_bit2 = (e_is_left_of_node6 && !(node7_children[5] && node8_is_left_of_node9) && !(node8_children[5])) ||
                 (e_is_left_of_node7 && !(node8_children[6])) ||
                 (e_is_left_of_node8 && !(node9_children[7])) ? 1'b0 : 1'b1;
    wire e_bit3 = e_is_left_of_node6 && node7_children[5] && node8_children[6] && node9_children[7] ? 1'b0 : 1'b1;
    
    assign code_e = (len_e == 4'd1) ? {3'b000, e_bit0} :
                   (len_e == 4'd2) ? {2'b00, e_bit0, e_bit1} :
                   (len_e == 4'd3) ? {1'b0, e_bit0, e_bit1, e_bit2} :
                   {e_bit0, e_bit1, e_bit2, e_bit3};
                   
    // Concatenate the codes in the order a to e
    assign out_encoded = {code_a, code_b, code_c, code_d, code_e};
    
endmodule