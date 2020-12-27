library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;

ENTITY snake_game IS
GENERIC (
	ref_clk_freq_g : integer := 60000000;
	update_clk_freq_g : integer := 3;
	btn_count_g : integer := 4;
	led_count_g : integer := 64
);
PORT(
	clk : IN std_logic;
	rst_n : IN std_logic;
	btn : IN std_logic_vector(btn_count_g - 1 DOWNTO 0);
	clk_out : OUT std_logic;
	load_out : OUT std_logic;
	dout : OUT std_logic
);
END snake_game;

ARCHITECTURE snake OF snake_game IS

--CONSTANTS
--max value for update_counter
CONSTANT update_counter_max_c : integer := ref_clk_freq_g / update_clk_freq_g;

--TYPES
TYPE directions IS (U, D, L, R);
TYPE snake_array IS ARRAY (led_count_g-1 DOWNTO 0) OF integer range 0 to led_count_g-1;

--SIGNALS
--player's location
SIGNAL player : integer range 0 to led_count_g-1;
--player's coordinates
SIGNAL player_coords : snake_array;
--player's direction
SIGNAL player_direction : directions;
--player's lenght
SIGNAL player_lenght : integer range 1 to led_count_g;
--point location
SIGNAL point : integer range 0 to led_count_g-1;
--next point's location
SIGNAL next_point : integer range 0 to led_count_g-1;
--led matrix data
SIGNAL led_matrix_data : std_logic_vector(led_count_g-1 DOWNTO 0);
--3Hz clk
SIGNAL update_clk : std_logic;
--signal used for updating player coordinates
SIGNAL update_coords : std_logic;
--counter used to create 3Hz clk
SIGNAL update_counter : integer;
--signal used for restart
SIGNAL restart : std_logic;

--COMPONENTS
COMPONENT max7219_controller IS
PORT(
	clk : IN std_logic;
	rst_n : IN std_logic;
	led_data : IN std_logic_vector(led_count_g-1 DOWNTO 0);
	restart : IN std_logic;
	data_out : OUT std_logic;
	mclock_out : OUT std_logic;
	load : OUT std_logic
);
END COMPONENT;

BEGIN

--Process for checking button presses, creating 3Hz clock and calculating next point position
PROCESS(clk, rst_n, restart)
BEGIN

	IF(rst_n = '0' or restart = '1') THEN
		next_point <= 0;
		update_clk <= '1';
		update_counter <= 0;
		update_coords <= '0';
		player_direction <= R;
		
	ELSIF(rising_edge(clk)) THEN
		--change player's direction if user presses button
		CASE player_direction IS
			WHEN U =>
				IF(btn(3) = '1') THEN
					player_direction <= L;
				ELSIF(btn(2) = '1') THEN
					player_direction <= R;
				END IF;
				
			
			WHEN D =>
				IF(btn(3) = '1') THEN
					player_direction <= L;
				ELSIF(btn(2) = '1') THEN
					player_direction <= R;
				END IF;
				
			
			WHEN R =>
				IF(btn(1) = '1') THEN
					player_direction <= U;
				ELSIF(btn(0) = '1') THEN
					player_direction <= D;
				END IF;
				
			
			WHEN L =>
				IF(btn(1) = '1') THEN
					player_direction <= U;
				ELSIF(btn(0) = '1') THEN
					player_direction <= D;
				END IF;
		
		END CASE;
		
		--create 3Hz clock
		IF(update_counter = update_counter_max_c/2) THEN
			update_clk <= '0';
			update_counter <= update_counter + 1;
		ELSIF(update_counter = update_counter_max_c) THEN
			update_clk <= '1';
			update_coords <= '0';
			update_counter <= 0;
		ELSIF(update_counter = (3*update_counter_max_c)/4) THEN
			update_coords <= '1';
			update_counter <= update_counter + 1;
		ELSE
			update_counter <= update_counter + 1;
		END IF;
		
		--calculates next position for point if player hits the current one
		IF(next_point = led_count_g-1) THEN
			next_point <= 0;
		ELSE
			next_point <= next_point + 1;
		END IF;
	END IF;
END PROCESS;

--Process for calculating players next position
PROCESS(update_clk, rst_n, restart)
BEGIN
	IF(rst_n = '0' or restart = '1') THEN
		player <= 20;
	ELSIF(falling_edge(update_clk)) THEN
		--calculate next position of player depending on player's direction
		CASE player_direction IS
			WHEN U =>
				IF(player = 7 or player = 15 or player = 23 or player = 31 or player = 39 or player = 47 or player = 55 or player = 63) THEN
					player <= player - 7;
				ELSE
					player <= player + 1;
				END IF;
				
			
			WHEN D =>
				IF(player = 0 or player = 8 or player = 16 or player = 24 or player = 32 or player = 40 or player = 48  or player = 56) THEN
					player <= player + 7;
				ELSE
					player <= player - 1;
				END IF;
				
			
			WHEN R =>
				IF(player = 56 or player = 57 or player = 58 or player = 59 or player = 60 or player = 61 or player = 62 or player = 63) THEN
					player <= player - 56;
				ELSE
					player <= player + 8;
				END IF;
				
			
			WHEN L =>
				IF(player = 0 or player = 1 or player = 2 or player = 3 or player = 4 or player = 5 or player = 6 or player = 7) THEN
					player <= player + 56;
				ELSE
					player <= player - 8;
				END IF;
		
		END CASE;
	END IF;
END PROCESS;

--Process for updating player coordiantes and checking if player hits itself or gets a point
PROCESS(update_coords, rst_n, restart)
BEGIN
	IF(rst_n = '0' or restart = '1') THEN
		player_coords <= (others => 0);
		player_coords(0) <= 4;
		player_coords(1) <= 12;
		player_coords(2) <= 20;
		player_lenght <= 3;
		point <= 41;
		restart <= '0';
	ELSIF(rising_edge(update_coords)) THEN
		FOR I IN 0 TO led_count_g-1 LOOP
			--if player hits itself restart the game
			IF(player = player_coords(I)) THEN
				restart <= '1';
			--if player hits the point
			ELSIF(player = point) THEN
				IF(I = player_lenght) THEN
					player_coords(I) <= player;
					player_lenght <= player_lenght + 1;
					point <= next_point;
					EXIT;
				END IF;
			ELSE
				--update player coordinates
				IF(I = player_lenght-1) THEN
					player_coords(I) <= player;
					EXIT;
				ELSIF(I < player_lenght-1) THEN
					player_coords(I) <= player_coords(I+1);
				END IF;
			END IF;
		END LOOP;
	END IF;
END PROCESS;

--Process for updating new led matrix data
PROCESS(update_clk, rst_n, restart)
BEGIN
	IF(rst_n = '0' or restart = '1') THEN
		led_matrix_data <= (others => '0');
	ELSIF(rising_edge(update_clk)) THEN
		--update led data with new data
		led_matrix_data <= (others => '0');
		FOR I IN 0 TO led_count_g-1 LOOP
			IF(I < player_lenght) THEN
				led_matrix_data(player_coords(I)) <= '1';
			ELSIF(I = player_lenght) THEN
				led_matrix_data(point) <= '1';
				EXIT;
			END IF;
		END LOOP;
	
	END IF;
	
END PROCESS;

max7219_controller_1 : max7219_controller
	PORT MAP(
		clk => clk,
		rst_n => rst_n,
		led_data => led_matrix_data,
		restart => restart,
		data_out => dout,
		mclock_out => clk_out,
		load => load_out
);

END snake;