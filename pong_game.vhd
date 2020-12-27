library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

ENTITY pong_game IS
GENERIC (
	ref_clk_freq_g : integer := 50000000;
	update_freg_g : integer := 5;
	btn_count_g : integer := 4
);
PORT(
	clk : IN std_logic;
	rst_n : IN std_logic;
	btn : IN std_logic_vector(btn_count_g - 1 DOWNTO 0);
	clk_out : OUT std_logic;
	load_out : OUT std_logic;
	dout : OUT std_logic
);
END pong_game;

ARCHITECTURE pong OF pong_game IS

-- CONSTANTS
CONSTANT update_counter_max_c : integer := ref_clk_freq_g / update_freg_g;
CONSTANT player_coord_max_c : integer := 6;
CONSTANT ball_position_max_c : integer := 63;
-- player size
CONSTANT player_size_c : integer := 3;
-- ball speed: 1="slow", 2="normal", 3="fast", 4="insane" etc.
CONSTANT ball_speed_c : integer := 2;
CONSTANT ball_update_counter_max_c : integer := ref_clk_freq_g/ball_speed_c;
-- ball's starting position
CONSTANT ball_start_position_c : integer := 20;

--TYPES
-- different directions that ball can go
TYPE directions IS (NE, E, SE, SW, W, NW);

--SIGNALS
-- players' positions
SIGNAL player1_position : integer;
SIGNAL player2_position : integer;
-- player row vectors
SIGNAL player1_row : std_logic_vector(7 DOWNTO 0);
SIGNAL player2_row : std_logic_vector(7 DOWNTO 0);
-- ball's position
SIGNAL ball_position : integer;
-- ball's direction
SIGNAL ball_direction : directions;
-- ball's coordinates in 6x8 vector
SIGNAL ball_coord : std_logic_vector(47 DOWNTO 0);
SIGNAL ball_update_counter : integer;
SIGNAL update_ball : std_logic;
SIGNAL update : std_logic;
SIGNAL update_counter : integer;
-- signal that stores the whole led matrix data
SIGNAL led_data : std_logic_vector(63 DOWNTO 0);

COMPONENT max7219_controller IS
PORT(
	clk : IN std_logic;
	rst_n : IN std_logic;
	led_data : IN std_logic_vector(63 DOWNTO 0);
	data_out : OUT std_logic;
	mclock_out : OUT std_logic;
	load : OUT std_logic	
);
END COMPONENT;

BEGIN

PROCESS(clk, rst_n)
BEGIN

	IF(rst_n = '0') THEN
		update <= '1';
		update_counter <= 0;
		update_ball <= '0';
		ball_update_counter <= 0;
	ELSIF(rising_edge(clk)) THEN
		-- create update clock signal
		IF(update_counter = update_counter_max_c/2) THEN
			update <= '0';
			update_counter <= update_counter + 1;
		ELSIF(update_counter = update_counter_max_c) THEN
			update <= '1';
			update_counter <= 0;
		ELSE
			update_counter <= update_counter + 1;
		END IF;
		
		-- create ball update clock signal
		IF(ball_update_counter = ball_update_counter_max_c/2) THEN
			update_ball <= '1';
			ball_update_counter <= ball_update_counter + 1;
		ELSIF(ball_update_counter = ball_update_counter_max_c) THEN
			update_ball <= '0';
			ball_update_counter <= 0;
		ELSE
			ball_update_counter <= ball_update_counter + 1;
		END IF;
	END IF;
END PROCESS;


-- process for calculating ball's next coordinate
PROCESS(update_ball, rst_n)
BEGIN
	
	IF(rst_n = '0') THEN
		ball_direction <= NE;
		ball_position <= ball_start_position_c;
	ELSIF(rising_edge(update_ball)) THEN
		-- if ball is going NE
		IF(ball_direction = NE) THEN
			-- if ball is at top right corner  and player is blocking the goal OR if ball hits players bottom dot
			IF((ball_position = 47 and ball_position-5*8 = player1_position + 2) or (ball_position-5*8 = player1_position)) THEN
				ball_direction <= SW;
				ball_position <= ball_position - 9;
			-- if ball hits players middle dot
			ELSIF(ball_position-5*8 = player1_position + 1) THEN
				ball_direction <= W;
				ball_position <= ball_position - 8;
			-- if ball hits players top dot
			ELSIF(ball_position-5*8 = player1_position + 2) THEN
				ball_direction <= NW;
				ball_position <= ball_position - 7;
			-- if ball hits the top
			ELSIF(ball_position = 15 or ball_position = 23 or ball_position = 31 or ball_position = 39) THEN
				ball_direction <= SE;
				ball_position <= ball_position + 7;
			-- if ball goes to goal
			ELSIF(ball_position = 41 or ball_position = 42 or ball_position = 43 or ball_position = 44 or ball_position = 45 or ball_position = 46 or ball_position = 47) THEN
				ball_position <= ball_start_position_c;
			ELSE
				ball_position <= ball_position + 9;
			END IF;
		
		-- if ball is going SE
		ELSIF(ball_direction = SE) THEN
			-- if ball is at bottom right corner  and player is blocking the goal OR if ball hits players top dot
			IF((ball_position = 40 and ball_position-5*8 = player1_position) or (ball_position-5*8 = player1_position + 2)) THEN
				ball_direction <= NW;
				ball_position <= ball_position - 7;
			-- if ball hits players bottom dot
			ELSIF(ball_position-5*8 = player1_position)THEN
				ball_direction <= SW;
				ball_position <= ball_position - 9;
			-- if ball hits players middle dot
			ELSIF(ball_position-5*8 = player1_position + 1) THEN
				ball_direction <= W;
				ball_position <= ball_position - 8;
			-- if ball hits the bottom
			ELSIF(ball_position = 8 or ball_position = 16 or ball_position = 24 or ball_position = 32) THEN
				ball_direction <= NE;
				ball_position <= ball_position + 9;
			-- if ball goes to goal
			ELSIF(ball_position = 40 or ball_position = 41 or ball_position = 42 or ball_position = 43 or ball_position = 44 or ball_position = 45 or ball_position = 46) THEN
				ball_position <= ball_start_position_c;
			ELSE
				ball_position <= ball_position + 7;
			END IF;
		
		-- if ball is going SW
		ELSIF(ball_direction = SW) THEN
			-- if ball is at bottom left corner and player is blocking the goal OR if ball hits players top dot
			IF((ball_position = 0 and ball_position = player2_position) or (ball_position = player2_position + 2)) THEN
				ball_direction <= NE;
				ball_position <= ball_position + 9;
			-- if ball hits players bottom dot
			ELSIF(ball_position = player2_position) THEN
				ball_direction <= SE;
				ball_position <= ball_position + 7;
			-- if ball hits players middle dot
			ELSIF(ball_position = player2_position + 1) THEN
				ball_direction <= E;
				ball_position <= ball_position + 8;
			-- if ball hits the bottom
			ELSIF(ball_position = 8 or ball_position = 16 or ball_position = 24 or ball_position = 32) THEN
				ball_direction <= NW;
				ball_position <= ball_position - 7;
			-- if ball goes to goal
			ELSIF(ball_position = 0 or ball_position = 1 or ball_position = 2 or ball_position = 3 or ball_position = 4 or ball_position = 5 or ball_position = 6) THEN
				ball_position <= ball_start_position_c;
			ELSE
				ball_position <= ball_position - 9;
			END IF;
		
		-- if ball is going NW
		ELSIF(ball_direction = NW) THEN
			-- if ball is at top left corner and player is blocking the goal OR if ball hits players bottom dot
			IF((ball_position = 7 and ball_position = player2_position + 2) or (ball_position = player2_position)) THEN
				ball_direction <= SE;
				ball_position <= ball_position + 7;
			-- if ball hits players middle dot
			ELSIF(ball_position = player2_position + 1) THEN
				ball_direction <= E;
				ball_position <= ball_position + 8;
			-- if ball hits players top dot
			ELSIF(ball_position = player2_position + 2) THEN
				ball_direction <= NE;
				ball_position <= ball_position + 9;
			-- if ball hits the top
			ELSIF(ball_position = 15 or ball_position = 23 or ball_position = 31 or ball_position = 39) THEN
				ball_direction <= SW;
				ball_position <= ball_position - 9;
			-- if ball goes to goal
			ELSIF(ball_position = 1 or ball_position = 2 or ball_position = 3 or ball_position = 4 or ball_position = 5 or ball_position = 6 or ball_position = 7) THEN
				ball_position <= ball_start_position_c;
			ELSE
				ball_position <= ball_position -7;
			END IF;
		
		-- if ball is going W
		ELSIF(ball_direction = W) THEN
			-- if ball hits players bottom dot
			IF(ball_position = player2_position) THEN
				ball_direction <= SE;
				ball_position <= ball_position + 7;
			-- if ball hits players middle dot
			ELSIF(ball_position = player2_position + 1) THEN
				ball_direction <= E;
				ball_position <= ball_position + 8;
			-- if ball hits players top dot
			ELSIF(ball_position = player2_position + 2) THEN
				ball_direction <= NE;
				ball_position <= ball_position + 9;
			-- if ball goes to goal
			ELSIF(ball_position = 1 or ball_position = 2 or ball_position = 3 or ball_position = 4 or ball_position = 5 or ball_position = 6) THEN
				ball_position <= ball_start_position_c;
			ELSE
				ball_position <= ball_position - 8;
			END IF;
		
		-- if ball is going E
		ELSIF(ball_direction = E) THEN
			-- if ball hits players bottom dot
			IF(ball_position-5*8 = player1_position)THEN
				ball_direction <= SW;
				ball_position <= ball_position - 9;
			-- if ball hits players middle dot
			ELSIF(ball_position-5*8 = player1_position + 1) THEN
				ball_direction <= W;
				ball_position <= ball_position - 8;
			-- if ball hits players top dot
			ELSIF(ball_position-5*8 = player1_position + 2) THEN
				ball_direction <= NW;
				ball_position <= ball_position - 7;
			-- if ball goes to goal
			ELSIF(ball_position = 41 or ball_position = 42 or ball_position = 43 or ball_position = 44 or ball_position = 45 or ball_position = 46) THEN
				ball_position <= ball_start_position_c;
			ELSE
				ball_position <= ball_position + 8;
			END IF;
		END IF;
	END IF;

END PROCESS;


-- process for checking button presses and for updating the players' and ball's positions on the led matrix
PROCESS(update, rst_n)
BEGIN
	IF(rst_n = '0') THEN
		player1_position <= 2;
		player2_position <= 2;
		player1_row <= "00011100";
		player2_row <= "00011100";
	
	ELSIF(rising_edge(update)) THEN
		
		-- update ball coordinates
		FOR I IN 0 TO 47 LOOP
			IF(I = ball_position) THEN
				ball_coord(I) <= '1';
			ELSE
				ball_coord(I) <= '0';
			END IF;
		END LOOP;
		
		-- button presses
		IF(btn(0) = '1') THEN
			-- if player 1 is at the bottom
			IF(player1_position = 0) THEN
				-- stay on the same space
				player1_position <= player1_position;
			ELSE
				-- move one up
				player1_position <= player1_position - 1;
			END IF;
			
		ELSIF(btn(1) = '1') THEN
			-- if player 1 is at the top
			IF(player1_position = 5) THEN
				-- stay on the same space
				player1_position <= player1_position;
			ELSE
				-- move one down
				player1_position <= player1_position + 1;
			END IF;
			
		ELSIF(btn(2) = '1') THEN
			-- if player 2 is at the bottom
			IF(player2_position = 0) THEN
				-- stay on the same space
				player2_position <= player2_position;
			ELSE
				-- move one down
				player2_position <= player2_position - 1;
			END IF;
			
		ELSIF(btn(3) = '1') THEN
			-- if player 2 is at the top
			IF(player2_position = 5) THEN
				-- stay on the same space
				player2_position <= player2_position;
			ELSE
				-- move one up
				player2_position <= player2_position + 1;
			END IF;
		END IF;
		
		-- update players' rows
		FOR I IN 0 TO 7 LOOP
			IF(I = player1_position or I-1 = player1_position or I-2 = player1_position) THEN
				player1_row(I) <= '1';
			ELSE
				player1_row(I) <= '0';
			END IF;
			
			IF(I = player2_position or I-1 = player2_position or I-2 = player2_position) THEN
				player2_row(I) <= '1';
			ELSE
				player2_row(I) <= '0';
			END IF;
		END LOOP;
		
		-- update led_data
		led_data <= player1_row & ball_coord & player2_row;
		
	END IF;
END PROCESS;

max7219_controller_1 : max7219_controller
	PORT MAP(
		clk => clk,
		rst_n => rst_n,
		led_data => led_data,
		data_out => dout,
		mclock_out => clk_out,
		load => load_out
);

END pong;