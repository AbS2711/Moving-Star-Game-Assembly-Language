# Moving-Star-Game-Assembly-Language
Using assembly language, I implemented a game that allows the user to navigate between obstacles with the goal of reaching the winning point without collisions. The game was made purely in Assembly language with all the movement logics implemented using scrolling.


Maze Navigator: x86 Assembly Game
This project is a grid-based Maze/Avoidance game written in 8086 Assembly language. It demonstrates low-level systems programming concepts including Memory-Mapped I/O, Hardware Interrupts, and Custom ISRs (Interrupt Service Routines).
## Game Objectives
The goal of the game is to navigate your player from the starting position to the target area while avoiding obstacles and screen boundaries.

Player Character: Represented by a light gray asterisk (*).

The Goal: A red square located at the top-left corner (Index 0) of the screen.

Obstacles: Green blocks scattered across the screen that trigger an immediate "Game Over" upon contact.

## Technical Features
### 1. Interrupt Service Routines (ISRs)
The game takes control of hardware interrupts to manage real-time gameplay:

Timer ISR (INT 8): Used to control the game pace. The player moves every 2 timer ticks to ensure the speed is playable and consistent.

Keyboard ISR (INT 9): Captures raw scan codes directly from the keyboard buffer (Port 0x60) for responsive controls.

### 2. Video Memory Manipulation
The game bypasses standard DOS interrupts for graphics, instead writing directly to the VGA Video Buffer starting at address 0xb800. This allows for:

Direct Character Placement: Instantly rendering obstacles, the goal, and the player.

Attribute Control: Managing background and foreground colors (e.g., Green for obstacles, Red for the goal).

### 3. Collision Logic
The engine performs a look-ahead check before updating the player's position:

Obstacle Check: Verifies if the next memory address contains the green block attribute (0x2220).

Goal Check: Verifies if the next memory address contains the red target attribute (0x4420).

Boundary Check: Prevents the player from wrapping around the screen or moving out of bounds.


## Controls
Use the standard Arrow Keys to change the direction of the player:

UP: Move toward the top of the screen.

DOWN: Move toward the bottom of the screen.

LEFT: Move toward the left edge.

RIGHT: Move toward the right edge.## How to Run
Assemble the code using NASM:
nasm game.asm -o game.com

Run the resulting file in a DOS environment or an emulator like DOSBox.

## Game States
Game Loop: The main loop continuously checks the movePlayerflag and the GameOver status.

Victory: Displays "Game WON" and uninstalls custom ISRs before returning to DOS.

Defeat: Displays "Game LOST" if you hit a wall or boundary.
