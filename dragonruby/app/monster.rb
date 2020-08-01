# frozen_string_literal: true

class Monster
  attr_accessor :tile, :sprite, :hp, :dead, :stunned

  def initialize(tile, sprite, hp)
    move(tile)
    @sprite = sprite
    @hp = hp
    @dead = false
    @attackedThisTurn = false
    @stunned = false
  end

  def update(s)
    if @stunned
      @stunned = false
      return
    end

    doStuff s
  end

  def doStuff(s)
    neighbors = tile.getAdjacentPassableNeighbors s.tiles

    neighbors = neighbors.select { |t| !t.monster || t.monster.isPlayer }

    if neighbors.length > 0
      playerTile = s.player.tile
      neighbors.sort! do |a, b|
        a.dist(playerTile) - b.dist(playerTile)
      end
      newTile = neighbors[0]
      tryMove s, newTile.x - tile.x, newTile.y - tile.y
    end
  end

  def draw(args)
    drawSprite args, sprite, tile.x, tile.y

    drawHP args
  end

  def drawHP(args)
    (0...hp).each do |i|
      drawSprite(
        args,
        9,
        tile.x + (i % 3) * (5 / 16),
        tile.y - (i / 3).floor * (5 / 16)
      )
    end
  end

  def tryMove(s, dx, dy)
    tiles = s.tiles
    newTile = tile.getNeighbor tiles, dx, dy
    if newTile.passable
      if !newTile.monster
        move(newTile)
      else
        if isPlayer != newTile.monster.isPlayer
          @attackedThisTurn = true
          newTile.monster.stunned = true
          newTile.monster.hit 1
        end
      end
      true
    end
  end

  def hit(damage)
    @hp -= damage
    die if @hp <= 0
  end

  def die
    @dead = true
    @tile.monster = nil
    @sprite = 1
  end

  def move(to_tile)
    @tile.monster = nil if @tile
    @tile = to_tile
    @tile.monster = self
  end

  def isPlayer
    false
  end

  ## Dragonruby output these instructions to enable serialization on our
  ## class, so we complied.
  # 1. Create a serialize method that returns a hash with all of
  #    the values you care about.
  def serialize
    {
      tile: tile,
      sprite: sprite,
      hp: hp
    }
  end

  # 2. Override the inspect method and return `serialize.to_s`.
  def inspect
    serialize.to_s
  end

  # 3. Override to_s and return `serialize.to_s`.
  def to_s
    serialize.to_s
  end
end

class Player < Monster
  def initialize(tile)
    super tile, 0, 3
  end

  def isPlayer
    true
  end

  def tryMove(s, dx, dy)
    game_tick s if super s, dx, dy
  end
end

class Bird < Monster
  def initialize(tile)
    super tile, 4, 3
  end
end

class Snake < Monster
  def initialize(tile)
    super tile, 5, 1
  end

  def doStuff(s)
    @attackedThisTurn = false
    super s

    super s unless @attackedThisTurn
  end
end

class Tank < Monster
  def initialize(tile)
    super tile, 6, 2
  end

  def update(s)
    started_stunned = @stunned
    super s
    @stunned = true unless started_stunned
  end
end

class Eater < Monster
  def initialize(tile)
    super tile, 7, 1
  end
end

class Jester < Monster
  def initialize(tile)
    super tile, 8, 2
  end
end
