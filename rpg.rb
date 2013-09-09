#to-do: the movement system for restricted (soon to be per turn) movement does not take into account impassable terrain and units.

#to-do: implement a turn system
# => pseudo code attempt 
# => 1) setup "end of turn" at end of play loop
# => 2) implement restricted movement per turn (create method to display possible movement options when a unit is selected, refresh every turn)
# => 3) turn class? unshift the map object to an array of set size (30?) such that 'rewinding time' abilities are possible in the future. could add auto save every number of array unshifts/turns (5?)

#to-do: add enemy units

#to-do: add enemy movement/ai

#to-do: inmplement unit interaction (combat)

require 'io/console' #required to read user input without "get"-style method
require 'yaml' #required to save and load maps as text files

####################
#                  # 
#     CLASSES      #
#                  #
####################

####################################
# Node for the map and sub-classes #
####################################

class Node
  
  attr_accessor :x, :y, :mov
  attr_reader :passable, :unit, :terrain, :rep, :basemov, :initx, :inity
  
  def initialize(x, y)
    @x, @y = type, x, y
  end
  
end

class End_of_map < Node
  
  def initialize(x, y)
    @x, @y = x, y
    @passable = false
    @unit = false
    @terrain = false
    @rep = "@"
  end
  
end

class Terrain < Node
  
  def initialize
    @terrain = true
    @unit = false
  end
  
end

class Unit < Node
  
  def initialize
    @terrain = false
    @unit = true
  end
  
  def reset_movement
    @mov = @basemov
    @initx, @inity = self.x, self.y
  end
  
end

class Featureless_terrain < Terrain
  
  def initialize(x, y)
    @x, @y = x, y
    @passable = true
    @rep = " "
  end

end

class Mountain_node < Terrain
  
  def initialize(x, y)
    @x, @y = x, y
    @passable = false
    @rep = "M"
  end
  
end

class Soldier_node < Unit
  
  def initialize(x, y)
    @x, @y = x, y
    @initx, @inity = @x, @y
    @passable = false
    @rep = "o"
    @basemov = 5
    @mov = @basemov
  end
  
end

class Enemy_soldier < Unit
  
  def initialize(x, y)
    @x, @y = x, y
    @initx, @inity = @x, @y
    @passable = false
    @rep = "x"
    @basemov = 5
    @mov = @basemov
  end
  
end

############################################

class Map
  
  attr_accessor :map, :playery, :playerx
  attr_reader :size, :hold, :stack
  
  def initialize(size)
    grid = []
    @size = size
    size += 2
    @stack, @enemy_stack = [], []
  
    ((size/2)+1).times do
      grid.push []
    end
  
    size.times do |i|
      grid[0].push End_of_map.new(i, 0)
      grid[-1].push End_of_map.new(i, -1)
    end
  
    i=1
    while i<((size/2))
      grid[i].push End_of_map.new(0, i)
      (size-2).times do |ii|
        square = rand
        if square <= 0.98 #.98 ##2% chance of tile being mountain
          grid[i].push Featureless_terrain.new(ii, i)
        else
          grid[i].push Mountain_node.new(ii, i)
        end
      end
      grid[i].push End_of_map.new(-1, i)
      i += 1
    end

    @map = grid
    return @map
  end
  
  def player
    return @map[@playery][@playerx]
  end

    
  def initialize_player(num)
    @playery = @size/4
    @playerx = (@size/2)-(num/2)
    @hold_terrain = @map[@playery][@playerx]
    num.times do |i|
      @map[@playery][@playerx+i] = Soldier_node.new(@playerx+i, @playery)
      @stack.push(@map[@playery][@playerx+i])
    end
    return @stack
  end
  
  def initialize_enemies(num)
    @enemyy = rand(1..size/2)
    @enemyx = rand(1..size-1)
    @enemy_hold = @map[@enemyy][@enemyx]
    num.times do |i|
      push = place_enemies(@enemyy, @enemyx+i)
      @enemy_stack.push(push)
    end
    return @enemy_stack
  end
  
  def place_enemies(y, x)
    if @map[y][x].class == NilClass || @map[y][x].passable == true
      @map[y][x] = Enemy_soldier.new(x, y)
      return @map[y][x]
    else
      add_sub = rand(0..1)
      if add_sub == 0
        place_enemies(y, x-rand(0..3))
      else
        place_enemies(y, x+rand(0..3))
      end
    end
  end
  
  def move_valid? (player)
    if self.player.passable == false
      return false
    end
    moves_used = (player.initx - self.playerx).abs + (player.inity - self.playery).abs
    if moves_used > player.basemov
      return false
    end
    return true
  end
  
  def move_player(direction, distance)
    
    #don't move the unit if it is out of moves
    if self.player.mov == 0
      return false
    end
    
    @hold_player = @map[@playery][@playerx] #save current player node
    @map[@playery][@playerx] = @hold_terrain #place previously held terrain node at     player's location
    case direction #change the player's coordinates as appropriate, but reverse the change if the node at that coordinate is not passable
    when "north"
      @playery -= distance
      if @map[@playery][@playerx].passable == false || self.move_valid?(@hold_player) == false
        @playery += distance
      end
    when "east"
      @playerx += distance
      if @map[@playery][@playerx].passable == false || self.move_valid?(@hold_player) == false
        @playerx-= distance
      end
    when "south"
      @playery += distance
      if @map[@playery][@playerx].passable == false || self.move_valid?(@hold_player) == false
        @playery-= distance
      end
    when "west"
      @playerx -= distance
      if @map[@playery][@playerx].passable == false || self.move_valid?(@hold_player) == false
        @playerx += distance
      end
    end
    
    @hold_terrain = @map[@playery][@playerx] #save the node at the current location (either pick up previous node if movement invalid or save new one)
    @map[@playery][@playerx] = @hold_player #place player node at current location
    @hold_player.x, @hold_player.y = @playerx, @playery #not sure if this is necessary
  end
  
  def print_grid
    @map.each_with_index do |x,i|
      @map[i].each do |y|
        putc y.rep.chomp
      end
      puts ""
    end
  end
  
end

####################
#                  # 
#     METHODS      #
#                  #
####################

def save_grid(map, filename)
  save_string = map.to_yaml
  File.open filename, 'w' do |f|
    if f.write save_string
      return true
    end
  end
  return false
end

def load_grid(filename)
  load_string = File.read filename
  map = YAML::load load_string
  return map
end

def generate_new_map
  while true
    puts ""
    puts "Enter map width (20-100)"
    size = gets.chomp.to_i
    if size > 100
      puts "Maximum size 100, please re-enter width."
    elsif size < 20 && size > 0
      puts "Minimum size 20, please re-enter width."
    elsif size == 0
      puts "Width must be between 20 and 100."
    else
      break
    end
  end
  grid = Map.new(size)
  return grid
end

####################
#                  # 
#    GAME SETUP    #
#                  #
####################

#welcome
puts "Hi.\n"

#later ask more details -- size of units, vary per person, random options etc.

#initialize unit stats

#later, randomize grid + other options


while true
  puts ""
  puts "(N)ew map or (L)oad map?"
  map_pref = gets.chomp.downcase
  if map_pref == "l"
      puts ""
      puts "What is the file name you'd like to load?"
      filename = gets.chomp
      basemap = load_grid(filename)
      unit_stack = basemap.stack
      unit_stack_counter = 1
    break
  elsif map_pref == "n"
    basemap = generate_new_map
    unit_pref = 0
    
    while unit_pref < 1 || unit_pref > 4
      puts ""
      puts "How many units would you like to start with?"
      unit_pref = gets.chomp.to_i
      puts "INVALID. Enter a number 1-4." unless unit_pref >= 1 && unit_pref <= 4
    end
    
    #create the requested units and add them to the "unit stack", which determines
    #in what order units are rotated through
    unit_stack = basemap.initialize_player(unit_pref)
    unit_stack_counter = 1
    
    enemy_stack = basemap.initialize_enemies(4)
    
    break
  else
    puts "N FOR NEW MAP L FOR LOAD, DUDE"
  end
end

basemap.print_grid

####################
#                  # 
#     GAMEPLAY     #
#                  #
####################

while true
  direction = nil #re-initialize direction to prevent repeat orders
  puts "Command?"
  command = STDIN.getch #gets.chomp.downcase
  case command
  when "q"
    puts "Thanks for playing!"
    break
  when "v"
    puts "Please enter a filename. If the file already exists, it will be replaced."
    filename = gets.chomp
    save_grid(basemap, filename)
  when "t"
    puts basemap.player.mov
  when "w"
    direction = "north"
  when "d"
    direction = "east"
  when "s"
    direction = "south"
  when "a"
    direction = "west"
  when "`"
    
    basemap.playery = unit_stack[unit_stack_counter].y unless unit_stack.length == 1
    basemap.playerx = unit_stack[unit_stack_counter].x unless unit_stack.length == 1
    
    if unit_stack_counter < unit_stack.length-1
      unit_stack_counter += 1
    else
      unit_stack_counter = 0
    end
    
  end
  if direction != nil
    basemap.move_player(direction, 1)
    system ("clear")
    basemap.print_grid
  end
end