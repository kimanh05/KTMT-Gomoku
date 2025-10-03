# Gomoku (Caro) game implemented in MIPS
# 15x15 board, Player 1 uses X, Player 2 uses O

.data
board:          .space 225     # 15x15 board (1 byte per cell)
welcome:        .asciiz "Welcome to Gomoku (Caro)!\n"
prompt1:        .asciiz "Player 1, Please enter your coordinates: "
prompt2:        .asciiz "Player 2, Please enter your coordinates: "
invalid_input:  .asciiz "Coordinate is invalid! Please enter your coordinates again.\n"
invalid_move:   .asciiz "Invalid move! Coordinates are out of range or already occupied.\n"
player1_win:    .asciiz "Player 1 wins!\n"
player2_win:    .asciiz "Player 2 wins!\n"
tie_message:    .asciiz "Tie!\n"

# Formatting strings for the board
colHeader:      .asciiz "     0   1   2   3   4   5   6   7   8   9  10  11  12  13  14\n"
horizontal_line:.asciiz "   +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+\n"
single_digit_space: .asciiz "  | " # Space padding for single-digit row numbers
double_digit_space: .asciiz " | "  # Space padding for two-digit row numbers
row_header:     .asciiz "  | "
pipe:           .asciiz " | "
newline:        .asciiz "\n"
x_symbol:       .asciiz "X"
o_symbol:       .asciiz "O"
empty_symbol:   .asciiz " "
comma:          .asciiz ","
result_file:    .asciiz "result.txt"

char_buffer:  .space 1
space:          .asciiz " "
file_descriptor: .word 0
row_buffer: .space 256


.text
.globl main

main:
    # Print welcome message
    li $v0, 4
    la $a0, welcome
    syscall
    
    # Initialize empty board
    jal init_board
    
    # Print initial board
    jal print_board
    
    # Start the game
    li $s0, 1         # $s0 = current player (1 or 2)
    li $s1, 0         # $s1 = number of turns played (to check for a draw)
    
game_loop:
    # Check if the board is full (tie)
    li $t0, 225         # 15x15 = 225 cells
    beq $s1, $t0, tie

    # Display prompt for the current player
    li $v0, 4
    beq $s0, 1, prompt_player1
    la $a0, prompt2
    j get_input
    
prompt_player1:
    la $a0, prompt1
    
get_input:
    syscall

    # Read coordinates from the user
    jal read_coordinates

    # Store coordinates into temporary registers
    move $s2, $v0       # Store x in $s2
    move $s3, $v1       # Store y in $s3

    # Check if the coordinates are valid
    move $a0, $s2       # x
    move $a1, $s3       # y
    jal is_valid_move
    beqz $v0, invalid_move_error

    # Make the move
    move $a0, $s2       # x from $s2
    move $a1, $s3       # y from $s3
    move $a2, $s0       # current player
    jal make_move

    # Increment move counter
    addi $s1, $s1, 1

    # Print the board
    jal print_board

    # Check for a win
    move $a0, $s2       # x from $s2
    move $a1, $s3       # y from $s3
    move $a2, $s0       # current player
    jal check_win
    bnez $v0, win

    # Switch player
    li $t0, 3
    sub $s0, $t0, $s0   # Toggle between 1 and 2

    j game_loop
    
invalid_move_error:
    # Print error message for invalid move
    li $v0, 4
    la $a0, invalid_move
    syscall
    j game_loop

win:
    # Print victory message
    li $v0, 4
    beq $s0, 1, player1_wins     # If $s0 == 1, then Player 1 wins
    li $s0, 'O'                  # Player 2 wins -> assign 'O'
    la $a0, player2_win
    j save_result
    
player1_wins:
    li $s0, 'X'                  # Player 1 wins -> assign 'X'
    la $a0, player1_win
    
save_result:
    syscall

    # Save the result to file
    jal open_output_file
    jal print_board_to_file
    j exit

tie:
    # Print tie message
    li $v0, 4
    la $a0, tie_message
    syscall

    li $s0, 0                    # Tie -> assign $s0 = 0

    jal open_output_file
    jal print_board_to_file
    j exit
 
exit:
    # Exit the program
    li $v0, 10
    syscall

# Initialize an empty board
init_board:
    la $t0, board       # Address of the board
    li $t1, 225         # Board size (15x15)
    li $t2, 0           # Counter
    li $t3, ' '         # Empty character
    
init_loop:
    beq $t2, $t1, init_done
    sb $t3, 0($t0)      # Store empty character in current cell
    addi $t0, $t0, 1    # Increment address
    addi $t2, $t2, 1    # Increment counter
    j init_loop
    
init_done:
    jr $ra

# Print the current board
print_board:
    # Save $ra because we will call other functions
    addi $sp, $sp, -4
    sw $ra, 0($sp)
    
    # Print column header (predefined)
    li $v0, 4
    la $a0, colHeader
    syscall
    
    # Print horizontal line
    la $a0, horizontal_line
    syscall
    
    # Print each row
    li $t0, 0           # Row counter

print_rows:
    bge $t0, 15, print_done
    
    # Print row number
    li $v0, 1
    move $a0, $t0
    syscall
    
    # Print spacing (align based on number of digits)
    li $v0, 4
    bge $t0, 10, double_digit_row  # If row number has 2 digits
    la $a0, single_digit_space     # Space for single-digit row: "  |"
    j print_row_space
    
double_digit_row:
    la $a0, double_digit_space     # Space for double-digit row: " |"
    
print_row_space:
    syscall
    
    # Print cells in the row
    li $t1, 0           # Column counter
    
print_cells:
    bge $t1, 15, print_row_done
    
    # Calculate index in the array
    mul $t2, $t0, 15
    add $t2, $t2, $t1
    la $t3, board
    add $t3, $t3, $t2
    lb $t4, 0($t3)      # Load character at current position
    
    # Print character
    li $v0, 11
    move $a0, $t4
    syscall
    
    # Print |
    li $v0, 4
    la $a0, pipe
    syscall
    
    addi $t1, $t1, 1    # Increment column counter
    j print_cells
    
print_row_done:
    # Print newline
    li $v0, 4
    la $a0, newline
    syscall
    
    # Print horizontal line
    la $a0, horizontal_line
    syscall
    
    addi $t0, $t0, 1    # Increment row counter
    j print_rows
    
print_done:
    # Restore $ra
    lw $ra, 0($sp)
    addi $sp, $sp, 4
    jr $ra
    
# Read coordinates from the user
read_coordinates:
    # Read input string
    li $v0, 8
    li $a1, 10              # Max input length
    la $a0, ($sp)           # Use stack as buffer
    addi $sp, $sp, -16      # Allocate space on the stack
    syscall

    # Parse string to extract x and y
    li $t0, 0               # x
    li $t1, 0               # y
    li $t2, 0               # State: 0 = reading x, 1 = reading y
    move $t3, $a0           # Pointer to input string

parse_loop:
    lb $t4, 0($t3)          # Load current character

    # Check for end of string or newline
    beq $t4, 0, parse_done
    beq $t4, 10, parse_done

    # Check for comma separator
    beq $t4, ',', comma_found

    # Validate digit character
    blt $t4, '0', invalid_input_error
    bgt $t4, '9', invalid_input_error

    # Convert ASCII digit to integer
    sub $t4, $t4, '0'

    # Add digit to x or y based on state
    beqz $t2, add_to_x

    # Add to y
    mul $t1, $t1, 10
    add $t1, $t1, $t4
    j next_char

add_to_x:
    # Add to x
    mul $t0, $t0, 10
    add $t0, $t0, $t4

next_char:
    addi $t3, $t3, 1        # Move to next character
    j parse_loop

comma_found:
    # Comma found, switch to reading y
    li $t2, 1
    addi $t3, $t3, 1        # Move to next character
    j parse_loop

invalid_input_error:
    # Print error message for invalid input
    li $v0, 4
    la $a0, invalid_input
    syscall

    # Re-read coordinates
    addi $sp, $sp, 16       # Free buffer space
    j read_coordinates
    
parse_done:
    # Check if no comma was found
    beqz $t2, invalid_input_error
    
    # Return x in $v0 and y in $v1
    move $v0, $t0
    move $v1, $t1
    
    addi $sp, $sp, 16   # Free the buffer
    jr $ra

# Check if the move is valid
# $a0 = x, $a1 = y
is_valid_move:
    # Check range
    bltz $a0, invalid_move_ret
    bge $a0, 15, invalid_move_ret
    bltz $a1, invalid_move_ret
    bge $a1, 15, invalid_move_ret
    
    # Check if the cell is already occupied
    mul $t0, $a0, 15
    add $t0, $t0, $a1
    la $t1, board
    add $t1, $t1, $t0
    lb $t2, 0($t1)
    bne $t2, ' ', invalid_move_ret
    
    # Valid move
    li $v0, 1
    jr $ra
    
invalid_move_ret:
    # Invalid move
    li $v0, 0
    jr $ra

# Make a move
# $a0 = x, $a1 = y, $a2 = player (1 or 2)
make_move:
    mul $t0, $a0, 15      # t0 = x * 15
    add $t0, $t0, $a1     # t0 = offset in board
    la $t1, board
    add $t1, $t1, $t0     # t1 = address of the cell

    li $t2, 'X'
    beq $a2, 2, set_O
    j write_symbol
set_O:
    li $t2, 'O'
write_symbol:
    sb $t2, 0($t1)
    
    # Return the placed coordinates
    move $v0, $a0
    move $v1, $a1
    jr $ra
    
    
# $a0 = x, $a1 = y, $a2 = player (1 or 2)
check_win:
    # Save registers
    addi $sp, $sp, -24
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)

    # Get player's symbol
    li $s0, 'X'
    beq $a2, 2, load_O
    j got_symbol
load_O:
    li $s0, 'O'
got_symbol:
    move $s1, $a0   # x
    move $s2, $a1   # y

    #### Vertical (dx=±1, dy=0)
    li $s3, 1
    li $s4, 0
    jal count_direction
    move $t0, $v0

    li $s3, -1
    li $s4, 0
    jal count_direction
    add $t0, $t0, $v0

    addi $t0, $t0, 1


    bge $t0, 5, win_found

    #### Horizontal (dx=0, dy=±1)
    li $s3, 0
    li $s4, 1
    jal count_direction
    move $t0, $v0

    li $s3, 0
    li $s4, -1
    jal count_direction
    add $t0, $t0, $v0

    addi $t0, $t0, 1


    bge $t0, 5, win_found

    #### Main diagonal (dx=±1, dy=±1)
    li $s3, 1
    li $s4, 1
    jal count_direction
    move $t0, $v0

    li $s3, -1
    li $s4, -1
    jal count_direction
    add $t0, $t0, $v0

    addi $t0, $t0, 1


    bge $t0, 5, win_found

    #### Anti-diagonal (dx=±1, dy=∓1)
    li $s3, 1
    li $s4, -1
    jal count_direction
    move $t0, $v0

    li $s3, -1
    li $s4, 1
    jal count_direction
    add $t0, $t0, $v0

    addi $t0, $t0, 1


    bge $t0, 5, win_found

    # No win
    li $v0, 0
    j check_win_done

win_found:
    li $v0, 1

check_win_done:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    addi $sp, $sp, 24
    jr $ra
    
    
# count_direction: counts the number of consecutive pieces of the same symbol in the direction (s3, s4)
# Input: s1 = x, s2 = y, s3 = dx, s4 = dy, s0 = player's symbol
# Output: v0 = number of consecutive pieces in the direction
count_direction:
    addi $sp, $sp, -16
    sw $ra, 0($sp)
    sw $t0, 4($sp)
    sw $t1, 8($sp)
    sw $t2, 12($sp)

    li $v0, 0           # counter = 0
    move $t0, $s1       # t0 = x
    move $t1, $s2       # t1 = y

count_loop:
    add $t0, $t0, $s3   # x += dx
    add $t1, $t1, $s4   # y += dy

    # Check if out of bounds
    bltz $t0, count_done
    bltz $t1, count_done
    bge $t0, 15, count_done
    bge $t1, 15, count_done

    # Calculate offset and get value at board[x][y]
    mul $t2, $t0, 15
    add $t2, $t2, $t1
    la $t3, board
    add $t3, $t3, $t2
    lb $t4, 0($t3)

    bne $t4, $s0, count_done  # if not the player's symbol -> stop

    addi $v0, $v0, 1          # increment counter

    j count_loop

count_done:
    lw $ra, 0($sp)
    lw $t0, 4($sp)
    lw $t1, 8($sp)
    lw $t2, 12($sp)
    addi $sp, $sp, 16
    jr $ra

# Save the result to a file
# $a0 = winning player (1, 2, or 0 if it's a draw), $a1 = result (1 = win, 0 = draw)
# Open the file for writing
open_output_file:
    li $v0, 13           # syscall 13 = open file
    la $a0, result_file     # file name
    li $a1, 1            # mode = write only
    li $a2, 0            # no special flags
    syscall
    sw $v0, file_descriptor
    jr $ra

# Write the game board to the file (similar to print_board but using syscall 15)
print_board_to_file:
    # Get file descriptor
    lw $a0, file_descriptor

    # Write the column header
    la $a1, colHeader
    li $a2, 63                # length of colHeader string
    li $v0, 15
    syscall

    # Write the horizontal line
    la $a1, horizontal_line
    li $a2, 64
    li $v0, 15
    lw $a0, file_descriptor
    syscall

    li $t0, 0                 # row: t0 = row index

print_file_rows:
    bge $t0, 15, print_file_done

    # Reset buffer pointer
    la $t5, row_buffer
    # Newline before each board row
    li $t6, '\n'
    sb $t6, row_buffer
    la $t5, row_buffer
    addi $t5, $t5, 1

    # Calculate row index
    move $t2, $t0
    li $t3, 10
    div $t2, $t3
    mflo $t6                # tens digit
    mfhi $t7                # units digit

    beqz $t6, single_digit_row

    # Print row index >= 10
    addi $t6, $t6, 48       # convert to character
    sb $t6, 0($t5)          # store tens digit
    addi $t5, $t5, 1

    addi $t7, $t7, 48
    sb $t7, 0($t5)          # store units digit
    addi $t5, $t5, 1

    li $t6, ' '             # add 1 space
    sb $t6, 0($t5)
    addi $t5, $t5, 1
    j after_row_label

single_digit_row:
    # Print row index < 10
    addi $t7, $t7, 48
    sb $t7, 0($t5)          # store units digit
    addi $t5, $t5, 1

    li $t6, ' '             # add 2 spaces
    sb $t6, 0($t5)
    addi $t5, $t5, 1
    sb $t6, 0($t5)
    addi $t5, $t5, 1

after_row_label:
    # Write '|'
    li $t6, '|'
    sb $t6, 0($t5)
    addi $t5, $t5, 1
    
    # Loop through each column (15 columns)
    li $t1, 0
print_file_cells:
    bge $t1, 15, finish_file_row

    li $t6, ' '
    sb $t6, 0($t5)
    addi $t5, $t5, 1

    mul $t2, $t0, 15
    add $t2, $t2, $t1
    la $t3, board
    add $t3, $t3, $t2
    lb $t6, 0($t3)

    sb $t6, 0($t5)
    addi $t5, $t5, 1

    li $t6, ' '
    sb $t6, 0($t5)
    addi $t5, $t5, 1
    li $t6, '|'
    sb $t6, 0($t5)
    addi $t5, $t5, 1

    addi $t1, $t1, 1
    j print_file_cells

finish_file_row:
    # End the row
    li $t6, '\n'
    sb $t6, 0($t5)
    addi $t5, $t5, 1

    # Write this row to the file
    la $a1, row_buffer
    sub $a2, $t5, $a1          # a2 = length
    lw $a0, file_descriptor
    li $v0, 15
    syscall

    # Write the horizontal line
    la $a1, horizontal_line
    li $a2, 64 
    li $v0, 15
    lw $a0, file_descriptor
    syscall

    addi $t0, $t0, 1
    j print_file_rows

print_file_done:

    # Write a newline before the result message
    li $t6, '\n'
    la $a1, row_buffer
    sb $t6, 0($a1)
    li $a2, 1
    lw $a0, file_descriptor
    li $v0, 15
    syscall

    # Check result and write appropriate message
    li $t1, 'X'
    beq $s0, $t1, write_p1_win

    li $t1, 'O'
    beq $s0, $t1, write_p2_win

    beqz $s0, write_tie

    j print_done_message

write_p1_win:
    la $a1, player1_win
    li $a2, 16             # length of the string "Player 1 wins!\n"
    lw $a0, file_descriptor
    li $v0, 15
    syscall
    j print_done_message

write_p2_win:
    la $a1, player2_win
    li $a2, 16             # length of the string "Player 2 wins!\n"
    lw $a0, file_descriptor
    li $v0, 15
    syscall
    j print_done_message

write_tie:
    la $a1, tie_message
    li $a2, 5             # length of the string "Tie!\n"

    lw $a0, file_descriptor
    li $v0, 15
    syscall

print_done_message:
    jr $ra




