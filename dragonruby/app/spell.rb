# frozen_string_literal: true

Spells = {
  WOOP: lambda {|s|
    s.player.move s, s.tiles.randomPassable
  },
  QUAKE: lambda {|s|
    (0...NumTiles).each do |i|
      (0...NumTiles).each do |j|
        tile = s.tiles.get i, j
        if tile.monster
          numWalls = 4 - tile.getAdjacentPassableNeighbors(s.tiles).length
          tile.monster.hit(s, numWalls * 2)
        end
      end
    end
    s.shakeAmount = 20
  },
  MAELSTROM: lambda {|s|
    s.monsters.each do |m|
        m.move(s, s.tiles.randomPassable)
        m.teleportCounter = 2
    end
  },
  MULLIGAN: lambda {|s|
    startLevel(s, 1, s.player.spells)
  },
  AURA: lambda {|s|
    s.player.tile.getAdjacentNeighbors(s.tiles).each do |t|
      t.setEffect(13)
      t.monster.heal(1) unless t.monster.nil?
    end
    s.player.tile.setEffect(13)
    s.player.heal(1)
  },
  DASH: lambda {|s|
    player  = s.player
    newTile = player.tile
    loop do
      lastMove = s.player.lastMove
      testTile = newTile.getNeighbor s.tiles, lastMove[0], lastMove[1]

      break unless testTile.passable && !testTile.monster

      newTile = testTile
    end

    return if player.tile == newTile

    player.move s, newTile
    newTile.getAdjacentNeighbors(s.tiles).each do |t|
      next if t.monster.nil?

      t.setEffect(14)
      t.monster.stunned = true
      t.monster.hit s, 1
    end
  },
  DIG: lambda {|s|
    (0...NumTiles).each do |i|
      (0...NumTiles).each do |j|
        tile = s.tiles.get i, j
        next if tile.passable

        s.tiles.replace tile, Floor
      end
    end
    s.player.tile.setEffect(13)
    s.player.heal(2)
  },
  KINGMAKER: lambda {|s|
    s.monsters.each do |m|
      m.heal(1)
      m.tile.treasure = true
    end
  },
  ALCHEMY: lambda {|s|
    s.player.tile.getAdjacentNeighbors(s.tiles).each do |t|
      s.tiles.replace(t, Floor).treasure = true if !t.passable && inBounds(t.x, t.y)
    end
  },
  POWER: lambda {|s|
    s.player.bonusAttack = 5
  },
  BUBBLE: lambda {|s|
    spells = s.player.spells
    (1...spells.length).reverse_each do |i|
      spells[i] = spells[i-1] if spells[i].nil?
    end
  },
  BRAVERY: lambda {|s|
    s.player.shield = 2
    s.monsters.each do |m|
      m.stunned = true
    end
  },
  BOLT: lambda {|s|
    lastMove = s.player.lastMove
    boltTravel(s, lastMove, 15 + lastMove[1].abs, 4)
  },
  CROSS: lambda {|s|
    directions = [
        [0, -1],
        [0, 1],
        [-1, 0],
        [1, 0]
    ]
    (0...directions.length).each do |k|
      boltTravel(s, directions[k], 15 + directions[k][1].abs, 2)
    end
  },
  EX: lambda {|s|
    directions = [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1]
    ]
    (0...directions.length).each do |k|
      boltTravel(s, directions[k], 14, 3)
    end
  }
}.freeze

def boltTravel(s, direction, effect, damage)
  newTile = s.player.tile
  tiles = s.tiles
  loop do
    testTile = newTile.getNeighbor(tiles, direction[0], direction[1])

    break unless testTile.passable

    newTile = testTile

    newTile.monster&.hit(s, damage)

    newTile.setEffect(effect)
  end
end
