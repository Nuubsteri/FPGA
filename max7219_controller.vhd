library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

ENTITY max7219_controller IS
GENERIC(
	ref_clk_freq_g : integer := 60000000;
	MAX7219_freq_g : integer := 10000000;
	packet_size_g : integer := 16;
	led_count_g : integer := 64

);
PORT
(
	clk : IN std_logic;
	rst_n : IN std_logic;
	led_data : IN std_logic_vector(led_count_g-1 DOWNTO 0);
	restart : IN std_logic;
	data_out : OUT std_logic;
	mclock_out : OUT std_logic;
	load : OUT std_logic
	
);
END max7219_controller;

ARCHITECTURE max7219 OF max7219_controller IS

--mclock counter max value
CONSTANT mclock_max_c : integer := ref_clk_freq_g / MAX7219_freq_g;
--led matrix row size
CONSTANT matrix_row_size_c : integer := 8;

TYPE data is array (0 to 11) of std_logic_vector(packet_size_g-1 DOWNTO 0);
--array which stores setup data
SIGNAL setup_data : data;
--counter used in choosing current_data
SIGNAL setup_counter : integer;
--signal that tells when setup is ready
SIGNAL setup_ready : std_logic;
--stores 16 bits which are send for led matrix
SIGNAL current_data : std_logic_vector(packet_size_g-1 DOWNTO 0);
--clock signal for led_matrix
SIGNAL mclock : std_logic;
--tells when mclock is started
SIGNAL mclock_started : std_logic;
--counter used for mclock
SIGNAL mclock_counter : integer;
--tells when next bit can be send to led matrix
SIGNAL send_bit : std_logic;
--counter that tells which bit to send
SIGNAL bit_counter : integer;
--signal that tells new 16 bits can be loaded
SIGNAL ready : std_logic;
--output data
SIGNAL dout : std_logic;
--load signal
SIGNAL ld : std_logic;

BEGIN

--Process to create 10MHz clock and control load
PROCESS(clk, rst_n, restart)
BEGIN

	
	IF(rst_n  = '0' or restart = '1') THEN
		mclock <= '0';
		mclock_counter <= 1;
		mclock_started <= '0';
		ld <= '1';
		bit_counter <= 16;
		send_bit <= '0';
		
		
	ELSIF(rising_edge(clk)) THEN
		--start 10MHz clock
		IF(mclock_started = '0') THEN
			mclock_started <= '1';
			ld <= '0';
		--if 10MHz has started
		ELSIF(mclock_started = '1') THEN
			IF(mclock_counter = mclock_max_c/2) THEN
				mclock <= '1';
				mclock_counter <= mclock_counter + 1;
			ELSIF(mclock_counter = mclock_max_c) THEN
				mclock <= '0';
				mclock_counter <= 1;
				IF(bit_counter = 1) THEN
					--set load to '1' and stop sending data
					ld <= '1';
					bit_counter <= bit_counter - 1;
				ELSIF(bit_counter = 0) THEN
					--set load to '0' and start sending new data
					ld <= '0';
					bit_counter <= 16;
				ELSE
					bit_counter <= bit_counter - 1;
				END IF;
			ELSIF(mclock_counter = mclock_max_c/4) THEN
				mclock_counter <= mclock_counter + 1;
				IF(bit_counter /= 0) THEN
					--send next bit
					send_bit <= '1';
				END IF;
			ELSE
				mclock_counter <= mclock_counter + 1;
				send_bit <= '0';
			END IF;
			
		END IF;
		
		
		
	END IF;

END PROCESS;

--Process for sending the new bit
PROCESS(rst_n, send_bit, restart)
BEGIN
	IF(rst_n = '0' or restart = '1') THEN
		dout <= '0';
		ready <= '1';
	ELSIF(rising_edge(send_bit)) THEN
		dout <= current_data(bit_counter-1);
		IF(bit_counter = 1) THEN
			--if all 16 bits have been sent set ready to '1' and load next 16 bits
			ready <= '1';
		ELSE
			ready <= '0';
		END IF;
	END IF;	
END PROCESS;


--Process for choosing  new current 16-bit data
PROCESS(ready, rst_n, restart)
BEGIN
	IF(rst_n = '0' or restart = '1') THEN
		setup_data(0) <= "0000000000000000";
		setup_data(1) <= "0000110000000001";
		setup_data(2) <= "0000101100001111";
		setup_data(3) <= "0000101000001111";
		setup_data(4) <= "0000000100000000";
		setup_data(5) <= "0000001000000000";
		setup_data(6) <= "0000001100000000";
		setup_data(7) <= "0000010000000000";
		setup_data(8) <= "0000010100000000";
		setup_data(9) <= "0000011000010000";
		setup_data(10) <= "0000011100000000";
		setup_data(11) <= "0000100000000000";
		setup_ready <= '0';
		setup_counter <= 0;
		current_data <= "0000000000000000";
		
	ELSIF(rising_edge(ready)) THEN
		IF(setup_ready = '0') THEN
			--send setup data
			CASE setup_counter is
				--Start up/do nothing
				WHEN 0 => current_data <= setup_data(setup_counter);
				--Set normal operation mode
				WHEN 1 => current_data <= setup_data(setup_counter); 
				--Set Enable all scan bits
				WHEN 2 => current_data <= setup_data(setup_counter); 
				--Set intensity to maximum
				WHEN 3 => current_data <= setup_data(setup_counter); 
				--clear row 1
				WHEN 4 => current_data <= setup_data(setup_counter); 
				--clear row 2
				WHEN 5 => current_data <= setup_data(setup_counter); 
				--clear row 3
				WHEN 6 => current_data <= setup_data(setup_counter); 
				--clear row 4
				WHEN 7 => current_data <= setup_data(setup_counter);
				--clear row 5
				WHEN 8 => current_data <= setup_data(setup_counter);
				--clear row 6				
				WHEN 9 => current_data <= setup_data(setup_counter); 
				--clear row 7
				WHEN 10 => current_data <= setup_data(setup_counter); 
				--clear row 8
				WHEN 11 => current_data <= setup_data(setup_counter); 
							setup_ready <= '1';
				WHEN others => 	current_data <= setup_data(0);
			END CASE;
			IF(setup_counter = 11) THEN
				setup_counter <= 7;
			ELSE
				setup_counter <= setup_counter + 1;
			END IF;
		ELSE
			--send led data row by row
			CASE setup_counter is
				WHEN 7 => current_data <= "00000001" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 6 => current_data <= "00000010" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 5 => current_data <= "00000011" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 4 => current_data <= "00000100" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 3 => current_data <= "00000101" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 2 => current_data <= "00000110" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 1 => current_data <= "00000111" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN 0 => current_data <= "00001000" & led_data((setup_counter+1) * matrix_row_size_c-1 DOWNTO (setup_counter+1) * matrix_row_size_c - matrix_row_size_c);
				WHEN others => 	current_data <= setup_data(0);
				
			END CASE;
			
			IF(setup_counter = 0) THEN
				setup_counter <= 7;
			ELSE
				setup_counter <= setup_counter - 1;
			END IF;
		
		END IF;
	END IF;
		
END PROCESS;

data_out <= dout;
mclock_out <= mclock;
load <= ld;

END max7219;