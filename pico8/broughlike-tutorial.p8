pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- broughlike-tutorial
-- ported by ryan1729

--
-- game
--

num_tiles=9
tile_size=16

screen_size = 128
spritesheet_pixel_width = 128
pixels_per_byte = 2
spritesheet_byte_width = spritesheet_pixel_width / pixels_per_byte
tile_byte_width = tile_size / pixels_per_byte

function sprite_tile_xy(sprite)
    return (sprite % 8), flr(sprite / 8)
end

function draw_sprite(sprite, x, y)
    local tx, ty = sprite_tile_xy(sprite)
    sspr(
        tx * tile_size,
        ty * tile_size,
        tile_size,
        tile_size,
        -- we offset the sprites by 8 so at least
        -- part of all the tiles can be seen
        x * tile_size + shake_x - 8,
        y * tile_size + shake_y - 8
    )
end

function sprite_to_i(sprite)
    local tx, ty = sprite_tile_xy(sprite)
    local i = ty * spritesheet_byte_width * tile_size + tx * tile_byte_width
    return i
end

title_char_width = 5
title_char_height = 6

function draw_title_text(text, text_y, color)
    -- + 1 to account for the spaces between characters
    local text_x = (screen_size - (#text * (title_char_width + 1)))/2
    pr(text, text_x, text_y, color)
end

score_char_width = 3
score_char_height = 5

function draw_score_text(text, text_y, color)
    -- + 1 to account for the spaces between characters
    local text_x = (screen_size - (#text * (score_char_width + 1)))/2
    print(text, text_x, text_y, color)
end


function show_title()
    cls(0)

    game_state = "title"

    draw_title_text("peek-brough 8", screen_size/2 - 2*(title_char_height + 1), 7)

    draw_scores()
end

function start_game()
    level = 1
    score = 0
    start_level(starting_hp)

    game_state = "running"
end

function start_level(player_hp, player_spells)
    spawn_rate = 15;
    spawn_counter = spawn_rate

    generate_level()

    player = player_class:new(random_passable_tile())
    player.hp = player_hp

    if(player_spells ~= nil) then
        player.spells = player_spells
    end
    spell_index = 1

    random_passable_tile():replace(exit)
end

function get_scores()
    local scores = {}
    for i=0,63,4 do
        local score_table = {
            score = dget(i),
            run = dget(i+1),
            total_score = dget(i+2),
            active = dget(i+3) > 0,
        }

        if (
            score_table.score > 0
            or score_table.run > 0
            or score_table.total_score > 0
            or score_table.active
        ) then
            add(scores, score_table)
        else
            -- negative numbers are invalid and all zeroes is the
            -- initial state, which is never a real score since run
            -- is always positive.
            break
        end
    end
    return scores
end

function add_score(score, won)
    local all_scores = get_scores()
    do
        local score_table = {
            score = score,
            run = 1,
            total_score = score,
            active = won,
        }

        local last_score = pop(all_scores)

        if(last_score ~= nil) then
            if(last_score.active) then
                score_table.run = min(last_score.run + 1, 0x7fff.ffff)
                score_table.total_score += last_score.total_score
            else
                add(all_scores, last_score)
            end
        end
        add(all_scores, score_table)
    end

    -- we only have space for 16 scores
    -- so we keep the newest one and the
    -- top scores of the remaining 15
    local last_score = pop(all_scores)

    local truncated_scores = {}

    sort(all_scores, function(a,b)
        return a.total_score > b.total_score
    end)

    for i=1,15 do
        local current = pop(all_scores)
        if current == nil then
            break
        end
        add(truncated_scores, current)
    end

    add(truncated_scores, last_score)

    -- save scores
    local index = 0
    for s in all(truncated_scores) do
        dset(index, s.score)
        index += 1
        dset(index, s.run)
        index += 1
        dset(index, s.total_score)
        index += 1
        dset(index, s.active and 1 or 0)
        index += 1

        if index > 63 then
            break
        end
    end
end

function draw_scores()
    local all_scores = get_scores()
    if(#all_scores > 0) then
        local score_y = screen_size/2 - (score_char_height + 1)
        draw_score_text(
            right_pad({"run","score","total"}),
            score_y,
            7
        )

        local newest_score = pop(all_scores)
        sort(all_scores, function(a,b)
            return a.total_score < b.total_score
        end)

        local sorted_scores = {newest_score}
        for s in all(all_scores) do
            add(sorted_scores, s)
        end

        for i=1,min(10,#sorted_scores) do
            local score_text = right_pad(
                {sorted_scores[i].run, sorted_scores[i].score, sorted_scores[i].total_score}
            )

            draw_score_text(
                score_text,
                score_y + i*(score_char_height + 1),
                i == 1 and 12 or 2
            )
        end
    end
end

-->8

--
-- map
--

function generate_level()
    try_to('generate map', function()
        return generate_tiles() == #(random_passable_tile():get_connected_tiles())
    end)

    generate_monsters()

    for i=1,3 do
        random_passable_tile().treasure = true
    end
end

function generate_tiles()
    local passable_tiles = 0

    tiles = {}
    for i=0,num_tiles do
        tiles[i] = {}
        for j=0,num_tiles do
            if (rnd(1) < 0.3 or not in_bounds(i, j)) then
                tiles[i][j] = wall:new(i,j)
            else
                tiles[i][j] = floor:new(i,j);

                passable_tiles += 1
            end
        end
    end

    return passable_tiles
end

function in_bounds(x,y)
    return x>0 and y>0 and x<num_tiles-1 and y<num_tiles-1
end

function get_tile(x, y)
    if(in_bounds(x,y)) then
        return tiles[x][y]
    else
        return wall:new(x,y)
    end
end

function random_passable_tile()
    local tile;
    try_to('get random passable tile', function()
        local x = flr(rnd(num_tiles))
        local y = flr(rnd(num_tiles))
        tile = get_tile(x, y);
        return tile.passable and not tile.monster;
    end);
    return tile
end

function generate_monsters()
    monsters = {};
    local num_monsters = level+1
    for i=0,num_monsters do
        spawn_monster()
    end
end

function spawn_monster()
    local monster_type = shuffle({bird, snake, tank, eater, jester})[1]
    local monster = monster_type:new(random_passable_tile())
    add(monsters, monster)
end

-->8

--
-- tile
--

tile = {}

function tile:new(x, y, sprite, passable)
    obj = {
        x = x,
        y = y,
        sprite = sprite,
        passable = passable,
        effect_counter = 0
    }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

function tile:step_on(monster)
  --needed for subclasses
end

function tile:replace(new_tile_type)
    tiles[self.x][self.y] = new_tile_type:new(self.x, self.y)
    return tiles[self.x][self.y]
end

function tile:dist(other)
  return abs(self.x-other.x)+abs(self.y-other.y);
end

effect_counter_start = 30
filled_pixels_estimate = (tile_size * tile_size) * 7 / 8
initial_remove_count = ceil(filled_pixels_estimate / effect_counter_start)

first_free_slot = 17
tile.free_effect_slot = first_free_slot

function tile:draw()
  draw_sprite(self.sprite, self.x, self.y)
  if (self.treasure) then
    draw_sprite(12, self.x, self.y)
  end
  if(self.effect_counter > 0) then
    -- set some pixels from the (copied) effect sprite to the
    -- transparent colour for a cheap fade out effect
    local base_address = sprite_to_i(self.effect)
    local remove_count = initial_remove_count
    local timeout = remove_count * 6
    while remove_count > 0 and timeout > 0 do
        local x = flr(rnd(tile_byte_width))
        local y = flr(rnd(tile_size))
        local i = base_address + y * spritesheet_byte_width + x
        local is_high_pixel = rnd(1) > 0.5
        local peeked = peek(i)
        local pixel = is_high_pixel and shr(band(peeked, 0xf0), 4) or band(peeked, 0x0f)
        if (pixel ~= transparent_colour) then
            local new_byte = is_high_pixel
                and bor(band(peeked, 0x0f), shl(transparent_colour, 4))
                or bor(band(peeked, 0xf0), transparent_colour)
            poke(i, new_byte)

            remove_count -= 1
        end
        timeout -= 1
    end

    self.effect_counter -= 1
    draw_sprite(self.effect, self.x, self.y)
  end
end

function tile:set_effect(effect_sprite)
    local free_i = sprite_to_i(tile.free_effect_slot)
    -- clear possibly re-used effect sprite
    for y=0, tile_size-1 do
        local offset = y * spritesheet_byte_width
        memset(free_i + offset, transparent_colour, tile_byte_width)
    end

    -- copy sprite data to an unused part of the spritesheet
    local i = sprite_to_i(effect_sprite)


    for y=0, tile_size-1 do
        local offset = y * spritesheet_byte_width
        memcpy(free_i + offset, i + offset, tile_byte_width)
    end

    -- set the effect sprite to the slot we copied, so we can edit the
    -- sprite and have the tile show the changes
    self.effect = tile.free_effect_slot
    tile.free_effect_slot += 1
    if (tile.free_effect_slot >= 64) then
        tile.free_effect_slot = first_free_slot
    end
    self.effect_counter = effect_counter_start
end

function tile:get_neighbor(dx, dy)
    return get_tile(self.x + dx, self.y + dy)
end

function tile:get_adjacent_neighbors()
    return shuffle({
        self:get_neighbor(0, -1),
        self:get_neighbor(0, 1),
        self:get_neighbor(-1, 0),
        self:get_neighbor(1, 0)
    });
end

function tile:get_adjacent_passable_neighbors()
    return filter(self:get_adjacent_neighbors(), function (t) return t.passable end);
end

function tile:get_connected_tiles()
    local connected_tiles = {self}
    local frontier = {self}
    while (#frontier > 0) do
        local neighbors = filter(
            pop(frontier):get_adjacent_passable_neighbors(),
            function (t) return not contains(connected_tiles, t) end
        )
        connected_tiles = concat(connected_tiles, neighbors)
        frontier = concat(frontier, neighbors)
    end
    return connected_tiles
end

floor = tile:new()

function floor:new(x, y)
  return tile.new(self, x, y, 2, true)
end

function floor:step_on(monster)
    if(monster.is_player and self.treasure) then
        score += 1
        if(score % 3 == 0 and num_spells < max_spell_index) then
            num_spells += 1
            player:add_spell()
        end

        sfx(treasure_sfx)
        self.treasure = false
        spawn_monster()
    end
end

wall = tile:new()

function wall:new(x, y)
  return tile.new(self, x, y, 3, false)
end

exit = tile:new()

function exit:new(x, y)
  return tile.new(self, x, y, 11, true)
end

function exit:step_on(monster)
    if(monster.is_player) then
        sfx(new_level_sfx)

        if(level == num_levels) then
            add_score(score, true)
            show_title()
        else
            level += 1
            start_level(min(max_hp, player.hp+1));
        end
    end
end

-->8

--
-- monster
--

monster = {}

function monster:new(tile, sprite, hp)
    obj = {
        sprite = sprite,
        hp = hp,
        teleport_counter = 2,
        offset_x = 0,
        offset_y = 0,
        last_move = {-1, 0},
        bonus_attack = 0
    }
    setmetatable(obj, self)
    self.__index = self
    obj:move(tile)
    return obj
end

function monster:heal(damage)
    self.hp = min(max_hp, self.hp + damage)
end

function monster:update()
    self.teleport_counter -= 1
    if(self.stunned or self.teleport_counter > 0) then
        self.stunned = false
        return
    end
    self:do_stuff()
end

function monster:do_stuff()
    local neighbors = self.tile:get_adjacent_passable_neighbors()

    neighbors = filter(neighbors, function(t)
        return (t.monster == nil) or t.monster.is_player
    end)

    if(#neighbors > 0) then
        sort(neighbors, function(a,b)
            return a:dist(player.tile) > b:dist(player.tile)
        end)
        local new_tile = neighbors[1]
        self:try_move(new_tile.x - self.tile.x, new_tile.y - self.tile.y);
    end
end

function monster:get_display_x()
    return self.tile.x + self.offset_x
end

function monster:get_display_y()
    return self.tile.y + self.offset_y
end

function monster:draw()
    if(self.teleport_counter > 0) then
        draw_sprite(10, self:get_display_x(), self:get_display_y())
    else
        draw_sprite(self.sprite, self:get_display_x(), self:get_display_y())

        self:draw_hp()
    end

    self.offset_x -= signum(self.offset_x)*(1/8)
    self.offset_y -= signum(self.offset_y)*(1/8)
end

function monster:draw_hp()
    for i=0,ceil(self.hp) - 1 do
        draw_sprite(
            9,
            self:get_display_x() + (i%3)*(5/16),
            self:get_display_y() - flr(i/3)*(5/16)
        )
    end
end

function monster:try_move(dx, dy)
    local new_tile = self.tile:get_neighbor(dx, dy)
    if(new_tile.passable) then
        self.last_move = {dx, dy}
        if(new_tile.monster == nil) then
            self:move(new_tile)
        else
            if (self.is_player ~= new_tile.monster.is_player) then
                self.attacked_this_turn = true
                new_tile.monster.stunned = true
                new_tile.monster:hit(1 + self.bonus_attack);
                self.bonus_attack = 0

                shake_amount = 5

                self.offset_x = (new_tile.x - self.tile.x)/2
                self.offset_y = (new_tile.y - self.tile.y)/2
            end
        end
        return true
    end
    return false
end


function monster:hit(damage)
   if(self.shield ~= nil and self.shield > 0) then
        return
    end
    self.hp -= damage
    if(self.hp <= 0) then
        self:die()
    end

    if self.is_player then
        sfx(player_hit_sfx)
    else
        sfx(monster_hit_sfx)
    end
end

function monster:die()
    self.dead = true
    self.tile.monster = nil
    self.sprite = 1
end

function monster:move(tile)
    if(self.tile ~= nil) then
        self.tile.monster = nil
        self.offset_x = self.tile.x == nil and 0 or self.tile.x - tile.x
        self.offset_y = self.tile.y == nil and 0 or self.tile.y - tile.y
    end
    self.tile = tile
    tile.monster = self
    tile:step_on(self)
end

player_class = monster:new(tile:new())

function player_class:new(tile)
    local player = monster.new(self, tile, 0, 3)

    player.is_player = true
    player.teleport_counter = 0
    player.shield = 0

    local shuffled_spells = shuffle(keys(spells))

    player.spells = {}
    for i=1,num_spells do
        add(player.spells, shuffled_spells[i])
    end

    return player
end

function player_class:update()
    self.shield -= 1
end

function player_class:try_move(dx, dy)
    if (monster.try_move(self, dx,dy)) then
        tick()
    end
end

function player_class:add_spell()
    local new_spell = shuffle(keys(spells))[1]
    for i=max_spell_index,1, -1 do
        if (self.spells[i] ~= nil) then
            self.spells[i + 1] = new_spell
        end
    end

end

function player_class:cast_spell(index)
    local spell_name = self.spells[index]
    if(spell_name ~= nil) then
        self.spells[index] = nil
        spells[spell_name]()
        sfx(spell_sfx)
        tick()
    end
end

bird = monster:new(tile:new())

function bird:new(tile)
    return monster.new(self, tile, 4, 3)
end

snake = monster:new(tile:new())

function snake:new(tile)
    return monster.new(self, tile, 5, 1)
end

function snake:do_stuff()
    self.attacked_this_turn = false
    monster.do_stuff(self)

    if (not self.attacked_this_turn) then
        monster.do_stuff(self)
    end
end

tank = monster:new(tile:new())

function tank:new(tile)
    return monster.new(self, tile, 6, 2)
end

function tank:update()
    local started_stunned = self.stunned
    monster.update(self)
    if(not started_stunned) then
        self.stunned = true
    end
end

eater = monster:new(tile:new())

function eater:new(tile)
    return monster.new(self, tile, 7, 1)
end

function eater:do_stuff()
    local neighbors = filter(
        self.tile:get_adjacent_neighbors(),
        function(t) return not t.passable and in_bounds(t.x,t.y) end
    )
    if (#neighbors > 0) then
        neighbors[1]:replace(floor)
        self:heal(0.5)
    else
        monster.do_stuff(self)
    end
end

jester = monster:new(tile:new())

function jester:new(tile)
    return monster.new(self, tile, 8, 2)
end

function jester:do_stuff()
    local neighbors = self.tile:get_adjacent_passable_neighbors()
    if (#neighbors > 0) then
        self:try_move(neighbors[1].x - self.tile.x, neighbors[1].y - self.tile.y);
    end
end

-->8

--
-- util
--

function try_to(description, callback)
    for timeout=1000, 0, -1 do
        if(callback()) then
            return
        end
    end
    assert(false, "timeout while trying to "..description)
end

function filter(tbl, predicate)
    local output = {}

    for i=1,#tbl do
        local v = tbl[i]
        if (predicate(v)) then
            add(output, v)
        end
    end

    return output
end

function pop(tbl)
    local len = #tbl
    local v = tbl[len]
    tbl[len] = nil
    return v
end

function concat(t1, t2)
    local output = {}

    local len1 = #t1
    for i=1,len1 do
        output[i] = t1[i]
    end

    for i=1,#t2 do
        output[len1 + i] = t2[i]
    end

    return output
end

function contains(tbl, elem)
    for e in all(tbl) do
        if (e == elem) return true
    end
    return false
end

function shuffle(arr)
    for i=1, #arr do
        local r = flr(rnd(i)) + 1
        arr[i], arr[r] = arr[r], arr[i]
    end
    return arr
end

function right_pad(text_array)
    local final_text = ""

    for text in all(text_array) do
        text=tostr(text)
        for i=#text,6 do
            text=text.." "
        end
        final_text = final_text..text
    end
    return final_text
end

-- https://www.lexaloffle.com/bbs/?pid=43636
-- converts anything to string, even nested tables
-- (max_depth added by ryan1729)
function tostring(any, max_depth)
  max_depth = max_depth or 16
  if (type(any)~="table" or max_depth <= 0) return tostr(any)
  local str = "{"
  for k,v in pairs(any) do
    if (str~="{") str=str..","
    str=str..tostring(k, max_depth - 1).."="..tostring(v, max_depth - 1)
  end
  return str.."}"
end

-- https://www.lexaloffle.com/bbs/?pid=50555#p
-- chosen for brevity
function sort(a,cmp)
  for i=1,#a do
    local j = i
    while j > 1 and cmp(a[j-1],a[j]) do
        a[j],a[j-1] = a[j-1],a[j]
        j = j - 1
    end
  end
end

-- the built-in `sgn` returns 1 if given 0. we want 0 in that case,
function signum(n)
    return n ~= 0 and sgn(n) or 0
end

function round(n)
    return flr(n + 0.5)
end

function keys(tbl)
    local output = {}
    for k, _ in pairs(tbl) do
        add(output, k)
    end

    -- we sort here so we get a consistent key ordering, which helps to
    -- ensure that all randomness is a function of the rng seed.
    sort(output, function(a,b) return a < b end)

    return output
end

-- setup for pr
fdat = [[  0000.0000! 739c.e038" 5280.0000# 02be.afa8$ 23e8.e2f8% 0674.45cc& 6414.c934' 2100.0000( 3318.c618) 618c.6330* 012a.ea90+ 0109.f210, 0000.0230- 0000.e000. 0000.0030/ 3198.cc600 fef7.bdfc1 f18c.637c2 f8ff.8c7c3 f8de.31fc4 defe.318c5 fe3e.31fc6 fe3f.bdfc7 f8cc.c6308 feff.bdfc9 fefe.31fc: 0300.0600; 0300.0660< 0199.8618= 001c.0700> 030c.3330? f0c6.e030@ 746f.783ca 76f7.fdecb f6fd.bdf8c 76f1.8db8d f6f7.bdf8e 7e3d.8c3cf 7e3d.8c60g 7e31.bdbch deff.bdeci f318.c678j f98c.6370k def9.bdecl c631.8c7cm dfff.bdecn f6f7.bdeco 76f7.bdb8p f6f7.ec60q 76f7.bf3cr f6f7.cdecs 7e1c.31f8t fb18.c630u def7.bdb8v def7.b710w def7.ffecx dec9.bdecy defe.31f8z f8cc.cc7c[ 7318.c638\ 630c.618c] 718c.6338^ 2280.0000_ 0000.007c``4100.0000`a001f.bdf4`bc63d.bdfc`c001f.8c3c`d18df.bdbc`e001d.be3c`f3b19.f630`g7ef6.f1fa`hc63d.bdec`i6018.c618`j318c.6372`kc6f5.cd6c`l6318.c618`m0015.fdec`n003d.bdec`o001f.bdf8`pf6f7.ec62`q7ef6.f18e`r001d.bc60`s001f.c3f8`t633c.c618`u0037.bdbc`v0037.b510`w0037.bfa8`x0036.edec`ydef6.f1ba`z003e.667c{ 0188.c218| 0108.4210} 0184.3118~ 02a8.0000`*013e.e500]]
cmap={}
for i=0,#fdat/11 do
 local p=1+i*11
 cmap[sub(fdat,p,p+1)]=
  tonum("0x"..sub(fdat,p+2,p+10))
end

-- https://www.lexaloffle.com/bbs/?tid=32877
-- by zed
function pr(str,sx,sy,col)
 local sx0=sx
 local p=1
 while (p <= #str) do
  local c=sub(str,p,p)
  local v

  if (c=="\n") then
   -- linebreak
   sy+=9 sx=sx0
  else
      -- single (a)
      v = cmap[c.." "]
      if not v then
       -- double (`a)
       v= cmap[sub(str,p,p+1)]
       p+=1
      end

   --adjust height
   local sy1=sy
   if (band(v,0x0.0002)>0)sy1+=2

   -- draw pixels
   for y=sy1,sy1+5 do
       for x=sx,sx+4 do
        if (band(v,0x8000)<0) pset(x,y,col)
        v=rotl(v,1)
       end
      end
      sx+=6
  end
  p+=1
 end
end

-->8

--
-- spell
--

spells = {
    woop = function()
        player:move(random_passable_tile())
    end,
    quake = function()
        for i=0,num_tiles do
            for j=0,num_tiles do
                local tile = get_tile(i,j)
                if(tile.monster ~= nil) then
                    local num_walls = 4 - #tile:get_adjacent_passable_neighbors()
                    tile.monster:hit(num_walls*2)
                end
            end
        end
        shake_amount = 20;
    end,
    maelstrom = function()
        for i=1,#monsters do
            monsters[i]:move(random_passable_tile())
            monsters[i].teleport_counter = 2;
        end
    end,
    mulligan = function()
        start_level(1, player.spells);
    end,
    aura = function()
        for t in all(player.tile:get_adjacent_neighbors()) do
            t:set_effect(13)
            if(t.monster ~= nil) then
                t.monster:heal(1)
            end
        end
        player.tile:set_effect(13)
        player:heal(1)
    end,
    dash = function()
        local new_tile = player.tile;
        while(true) do
            local test_tile = new_tile:get_neighbor(player.last_move[1],player.last_move[2])
            if(test_tile.passable and not test_tile.monster) then
                new_tile = test_tile
            else
                break
            end
        end
        if(player.tile != new_tile) then
            player:move(new_tile)
            for t in all(new_tile:get_adjacent_neighbors()) do
                if(t.monster) then
                    t:set_effect(14)
                    t.monster.stunned = true
                    t.monster:hit(1)
                end
            end
        end
    end,
    dig = function()
        for i=0,num_tiles do
            for j=0,num_tiles do
                local tile = get_tile(i,j)
                if(not tile.passable) then
                    tile:replace(floor)
                end
            end
        end
        player.tile:set_effect(13)
        player:heal(2)
    end,
    kingmaker = function()
        for i=1,#monsters do
            monsters[i]:heal(1)
            monsters[i].tile.treasure = true
        end
    end,
    alchemy = function()
        for t in all(player.tile:get_adjacent_neighbors()) do
            if(not t.passable and in_bounds(t.x, t.y)) then
                t:replace(floor).treasure = true
            end
        end
    end,
    power = function()
        player.bonus_attack = 5
    end,
    bubble = function()
        for i=#player.spells,2,-1 do
            if(player.spells[i] == nil) then
                player.spells[i] = player.spells[i-1]
            end
        end
    end,
    bravery = function()
        player.shield = 2
        for i=1,#monsters do
            monsters[i].stunned = true
        end
    end,
    bolt = function()
        bolt_travel(player.last_move, 15 + abs(player.last_move[2]), 4)
    end,
    cross = function()
        local directions = {
            {0, -1},
            {0, 1},
            {-1, 0},
            {1, 0}
        };
        for k=1,#directions do
            bolt_travel(directions[k], 15 + abs(directions[k][2]), 2)
        end
    end,
    ex = function()
        local directions = {
            {-1, -1},
            {-1, 1},
            {1, -1},
            {1, 1}
        };
        for k=1,#directions do
            bolt_travel(directions[k], 14, 3)
        end
    end
}

function bolt_travel(direction, effect, damage)
    local new_tile = player.tile;
    while (true) do
        local test_tile = new_tile:get_neighbor(direction[1], direction[2]);
        if(test_tile.passable) then
            new_tile = test_tile
            if(new_tile.monster ~= nil) then
                new_tile.monster:hit(damage)
            end
            new_tile:set_effect(effect)
        else
            break
        end
    end
end

-->8

--
-- main
--

level=1
max_hp=6
starting_hp = 3
num_levels = 6
max_spell_index = 9
max_spell_label_width = 12

monster_hit_sfx = 0
player_hit_sfx = 1
treasure_sfx = 2
new_level_sfx = 3
spell_sfx = 4

game_state = "title"
shake_amount = 0
shake_x = 0
shake_y = 0

spell_index = 1
num_spells = 1

transparent_colour = 15

function _init()
  cartdata("ryan1729_peek-brough-8_1")

  palt(0, false)
  palt(transparent_colour, true)

  show_title()
end

function _draw()
    if (game_state == "running" or game_state == "dead") then
        cls(13)

        screenshake()

        for i=0,num_tiles do
            for j=0,num_tiles do
                get_tile(i, j):draw()
            end
        end

        for i=1,#monsters do
            monsters[i]:draw()
        end

        player:draw()

        print("level: "..level, 8, 0, 2)
        print("score: "..score, 56, 0, 2)

        for i=1,max_spell_index do
            local spell_text = i..") "..(player.spells[i] == nil and "" or player.spells[i])

            local x = 8 + (i - spell_index) * (score_char_width + 1) * max_spell_label_width

            print(
                spell_text,
                x,
                screen_size - (score_char_height + 1),
                12
            )

            if (i == spell_index) then
                print("____________", x, screen_size - score_char_height, 10)
            end
        end
    end
end

function screenshake()
    if(shake_amount > 0) then
        shake_amount -= 1
    end
    -- pico-8 uses angles in the range 0 to 1
    local shake_angle = rnd(1)
    shake_x = round(cos(shake_angle)*shake_amount)
    shake_y = round(sin(shake_angle)*shake_amount)
end

function tick()
    for k=#monsters,1,-1 do
        if(not monsters[k].dead) then
            monsters[k]:update()
        else
            del(monsters, monsters[k])
        end
    end

    player:update()

    if(player.dead) then
        add_score(score, false)
        game_state = "dead"
    end

    spawn_counter -= 1
    if(spawn_counter <= 0) then
        spawn_monster()
        spawn_counter = spawn_rate
        spawn_rate -= 1
    end
end

function _update60()
    if(game_state == "title") then
        if (btnp() > 0) start_game()
    elseif(game_state == "dead") then
        if (btnp() > 0) show_title()
    elseif(game_state == "running") then
        if (btnp(0)) player:try_move(-1, 0)
        if (btnp(1)) player:try_move(1, 0)
        if (btnp(2)) player:try_move(0, -1)
        if (btnp(3)) player:try_move(0, 1)

        if (btnp(4)) player:cast_spell(spell_index)
        if (btnp(5)) then
            spell_index = spell_index + 1
            if (spell_index > 9) spell_index = 1
        end


    else
        assert(false, "unknown game_state ".. game_state)
    end
end

__gfx__
ffffffffffffffffffffffffffffffff11111111111111111133333333333311fffffffffffffffffffffffffffffffffffffffffffffffffddffddfffffffff
fffffbffbfff4fffffffffffffffffff11111111111111111333333333333331ffffffffffffffffffffddd666ffffffffffffffcccccfffd555555ddfffffff
fffffbbbbbfff4ffffffffffffffffff11111111111111113333333333333333ffffffffffffffffffffddddd6666ffffcccfffcdddddcff55555555dddddfff
fffffbfbfb3ff44fffffffffffffffff11111111111111113333333333333333fffeeeffffffffffff6ddd66fbfb66fffcddcccddc66cdcf55ddd555dd55dddf
fbbffbbbb33fff4fffffffffffffffff11111111111111113333333333333333666ef8efffffffffff66dd66fffffffffcdcdcddc6ddcdcf5d111d555d575ddf
fbbfff33333fff4ffffbb3bbbbbbbb3311111111111111113333333333333333f6688eeffffffffff666ffd6fbfbffffffcd6cdcdddcd6cfff5111dd55555d5f
ff3334433444ff4fffbbbb3bbbbbbbb311111111111111113333333333333333fff8888efffffffe6666fffd66666fffffcdcdddddddccfffff51111d555dd5d
ffffff4444433bbffbb033343333333411111111111111113333333333333333fff8eeeeeffffeef666fffffdd6ffff6ffcdddcddcddcfffffff51111dd5555d
ffffff34443ffbbff83bb83b4333334411111111111111113333333333333333fff88eeeeeeee8ff666ffbffffffff6ffccdddcddcddcfffffff5111111dd555
fffffbb343bfff4f88303833b43bb33311111111111111113333333333333333fff8e8ee8eee8fffd66666fffffff6dffcddddddddddcffffff51111111111d5
fffffbbb3bbfff4f833338883b33bbb411111111111111113333333333333333fff888e8e8e8ffffd66fffffff6bf6fffcdd6ddddd6d6fffff5111111111dd55
fffffbb33bbff4ff883388883b888f4411111111111111113333333333333333ffff8888e88fffffd666ff6bff6ff6ffffcdc6ddd6dcfffff511111111dd555f
fffffb3333bfffff88b888888388fff411111111111111113333333333333333fffff88888ffffffdd66ff6fff6f6dffffcddc66cdd6fffff5111111dd55555f
fffffb3333bbfffffb888ffff33fffff11111111111111113333333333333333fffff6fff6fffffffdd6666fff666ffffffcdddddd6ffffff5d111dd555555ff
ffff4433344bffff3bffff444334444f11111111111111111333333333333331fffff6fff6ffffffffdd66666666dfffffffccc666fffffff55ddd555fffffff
fff444333444ffff33ff44fffffffff411111111111111111133333333333311ffff6fff6ffffffffffdddd666ddffffffffffffffffffffff55555fffffffff
fffffeeeeeddffffffffffffffffffffffffffffff1111ff1111177777711111ffffffffffffffffff33ffff3fff33fff008888000f0f0ffffffffffffffffff
ffeeeee66eeeedfffffffffffffffffffffffffff11bb11f1111700000077771fffffffffffffffff3113ffffff3113f0888998880000f0fffffffffffffffff
fefdee6666dddedfffffffffffffffff111f111111b11b1f117700000a000007ffffffffffffffff31bb13fbff31bb1308999999888800f0ffffffffffffffff
efffd556655dffefffffffffffffffff1b111bbbbbb1111f170000aa00000a07ffffffff5fffffff31bb13ffff31bb13889aaaa99998880fffffffffffffffff
ffffd56ee65dffdfffffffffffffffffb111b111111b111f170a00aa00aa0007fffffff595fffffff3113ff33ff3113f899a77aaaa9998007777ffffffffffff
ffffd56ee65dfdffffffffffffffffffb11b11bbbb11b11f1700000000aa0071ffffff59d95fffffff33ff3113ff33ff899a77777aaa988078877fffffffffff
ffffdd5665ddffffffffffffffffffff1bb11b1111b11b1f1700a00000000771fffff59ddd95ffff3ffff31bb13ffff3889aa777777a998087e8777777777777
fffffdd55dddffffffffffffffffffff11b1b11bb11b1b1f17000000a0000007ffff59dd7dd95ffffff3f31bb13ffbff0899a777777a9980e7788e77e88e7788
fffffdddddddfffffffffffffffffffff1b1b11b11b11b1f700aa00000000a07ffff59d7eed95ffffbffff3113fffffff889a7777aaa98807777788e8788e8e7
fffffddedddffffdfffffffffffffffff1b1b11bbb11b11f700aa00a00000007ffff59dee7d95ffffff33ff33ff33ff30089a7777a99980fffff77e8777e8877
ffdfffdedddfffddf0000ffffffffffff1b11b11111b11117000000000aa0071ffff59dd7dd95fffff3113ffff3113fff089aa77aa988800fffff7777f77777f
fdefffdedddfffdf008200fffffffffff11b11bbbbb11bb1700000a000aa0071fffff59ddd95fffff31bb13ff31bb13f00899a77a998000fffffffffffffffff
deffffeeddefffdf087820ffffffffffff11b1111111b11b1777000000000071ffffff59d95ffffff31bb13ff31bb13ff0889aaaa98800ffffffffffffffffff
eefffeeefdeffedf088820fffffffffff1111bbbbbbb111b111700000a00a071fffffff595ffffffff3113ffff3113ff0f08999999800f0fffffffffffffffff
deeeeeefffdeeddf002200fffffffffff1b11b11111111b11117007700000071ffffffff5fffffff3ff33fffbff33ffff0f888998880f0ffffffffffffffffff
fdddddffffffddfff0000ffffffffffff11bb11ffffff1111111771177777711ffffffffffffffffffffff3ffffffff3ff0f0888800f0fffffffffffffffffff
fffffff7e877ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffff77787ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffff77e87ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffff78877ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffff77877fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff778e7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff7e877ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff78e77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff778e7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffff7787ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff77887ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff7e8e7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff78e77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff78877ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffff77e87ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffff7787ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
__label__
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333331133333333333333113333333333333311333333333333331133333333333333113333333333333311333333333333331133333333333333113333333
33333311113333333333331111333333333333111133333333333311113333333333331111333333333333111133333333333311113333333333331111333333
33333311111111111111111111111111111111111133333333333311111111111111111111111111111111111111111111111111111117777771111111333333
33333331111111111111111111111111111111111333333333333331111111111111111111111111111111111111111111111111111170000007777113333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111117700000a00000733333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111170000aa00000a0733333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111170a00aa00aa000733333333
333333331111111111111111111111111111111133333333333333331111111111111111111111111111111111111111111111111700000000aa007133333333
333333331111111111111111111111111111111133333333333333331111111111111111111111111111111111111111111111111700a0000000077133333333
3333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111117000000a000000733333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111700aa00000000a0733333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111700aa00a0000000733333333
333333331111111111111111111111111111111133333333333333331111111111111111111111111111111111111111111111117000000000aa007133333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111700000a000aa007133333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111177700000000007133333333
33333333111111111111111111111111111111113333333333333333111111111111111111111111111111111111111111111111111700000a00a07133333333
33333331111111111111111111111111111111111333333333333331111111111111111111111111111111111111111111111111111700770000007113333333
33333311111111111111111111111111111111111133333333333311111111111111111111111111111111111111111111111111111177117777771111333333
33333311113333333333331111111111111111111111111111111111113333333333331111111111111111111111111111111111111111111111111111333333
33333331133333333333333111111111111111111111111111111111133333333333333111111111111111111111111111111111111111111111111113333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333333333333333333333311111111111111111111111111111111333333333333333311111111111111111111111111111111111111111111111133333333
33333331133333333333333111111111111111111111111111111111133333333333333111111111111111111111111111111111111111111111111113333333
33333311113333333333331111111111111111111111111111111111113333333333331111111111111111111111111111111111111111111111111111333333
3333331111333333333333111111111111111111113333333333331111333333333333111dd11dd1111111111111111111111111113333333333331111333333
33333331133333333333333111111111ccccc11113333333333333311333333333333331d555555dd11111111111111111111111133333333333333113333333
3333333333333333333333331ccc111cdddddc113333333333333333333333333333333355555555ddddd1111111111111111111333333333333333333333333
3333333333333333333333331cddcccddc66cdc13333333333333333333333333333333355ddd555dd55ddd11111111111111111333333333333333333333333
3333333333333333333333331cdcdcddc6ddcdc1333333333333333333333333333333335d111d555d575dd11111111111111111333333333333333333333333
33333333333333333333333311cd6cdcdddcd6c133333333333333333333333333333333115111dd55555d511111111111111111333333333333333333333333
33333333333333333333333311cdcdddddddcc113333333333333333333333333333333311151111d555dd5d1111111111111111333333333333333333333333
33333333333333333333333311cdddcddcddc11133333333333333333333333333333333111151111dd5555d1111111111111111333333333333333333333333
3333333333333333333333331ccdddcddcddc1113333333333333333333333333333333311115111111dd5551111111111111111333333333333333333333333
3333333333333333333333331cddddddddddc1113333333333333333333333333333333311151111111111d51111111111111111333333333333333333333333
33333333333333333333333310000d00006d611133333333333333333333333333333333100001000011dd551111111111111111333333333333333333333333
33333333333333333333333300820008200c11113333333333333333333333333333333300820008200d55511111111111111111333333333333333333333333
33333333333333333333333308782087820611113333333333333333333333333333333308782087820555511111111111111111333333333333333333333333
33333333333333333333333308882088820111113333333333333333333333333333333308882088820555111111111111111111333333333333333333333333
33333331133333333333333100220002200111111333333333333331133333333333333100220002200111111111111111111111133333333333333113333333
33333311113333333333331110000100001111111133333333333311113333333333331110000500001111111111111111111111113333333333331111333333
33333311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111333333
3333333111111111111111111111111111111111111111111111111111111b11b111411111111111111111111111111111111111111111111111111113333333
3333333311111111111111111111111111111111111111111111111111111bbbbb11141111111111111111111111111111111111111111111111111133333333
3333333311111111111111111111111111111111111111111111111111111b1b1b31144111111111111111111111111111111111111111115111111133333333
333333331111111111111111111111111111111111111111111111111bb11bbbb331114111111111111111111111111111111111111111159511111133333333
333333331111111111111111111111111111111111111111111111111bb11133333111411111111111111111111111111111111111111159d951111133333333
333333331111111111111111111111111111111111111111111111111133344334441141111111111111111111111111111111111111159ddd95111133333333
333333331111111111111111111111111111111111111111111111111111114444433bb111111111111111111111111111111111111159dd7dd9511133333333
333333331111111111111111111111111111111111111111111111111111113444311bb111111111111111111111111111111111111159d7eed9511133333333
3333333311111111111111111111111111111111111111111111111111111bb343b1114111111111111111111111111111111111111159dee7d9511133333333
3333333311111111111111111111111111111111111111111111111110000b0000b0000111111111111111111111111111111111111159dd7dd9511133333333
333333331111111111111111111111111111111111111111111111110082000820008200111111111111111111111111111111111111159ddd95111133333333
3333333311111111111111111111111111111111111111111111111108782087820878201111111111111111111111111111111111111159d951111133333333
33333333111111111111111111111111111111111111111111111111088820888208882011111111111111111111111111111111111111159511111133333333
33333331111111111111111111111111111111111111111111111111002200022000220011111111111111111111111111111111111111115111111113333333
33333311111111111111111111111111111111111111111111111111100004000040000111111111111111111111111111111111111111111111111111333333
33333311111111111111111111111eeeeedd11111111111111111111111111111111111111111111111111111111111111111111111111111111111111333333
33333331111111111111111111eeeee66eeeed111111111111111111111111111111111111111111111111111111111111111111111111111111111113333333
3333333311111111111111111e1dee6666ddded11111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
333333331111111111111111e111d556655d11e11111111111111111111111111111111111111111511111111111111111111111111111111111111133333333
3333333311111111111111111111d56ee65d11d11111111111111111111111111111111111111115951111111111111111111111111111111111111133333333
3333333311111111111111111111d56ee65d1d111111111111111111111111111111111111111159d95111111111111111111111111111111111111133333333
3333333311111111111111111111dd5665dd1111111111111111111111111111111111111111159ddd9511111111111111111111111111111111111133333333
33333333111111111111111111111dd55ddd111111111111111111111111111111111111111159dd7dd951111111111111111111111111111111111133333333
33333333111111111111111111111ddddddd111111111111111111111111111111111111111159d7eed951111111111111111111111111111111111133333333
33333333111111111111111111111ddeddd1111d11111111111111111111111111111111111159dee7d951111111111111111111111111111111111133333333
3333333311111111111111111000010000d111dd11111111111111111111111111111111111159dd7dd951111111111111111111111111111111111133333333
33333333111111111111111100820008200111d1111111111111111111111111111111111111159ddd9511111111111111111111111111111111111133333333
33333333111111111111111108782087820111d11111111111111111111111111111111111111159d95111111111111111111111111111111111111133333333
3333333311111111111111110888208882011ed11111111111111111111111111111111111111115951111111111111111111111111111111111111133333333
33333331111111111111111100220002200eedd11111111111111111111111111111111111111111511111111111111111111111111111111111111113333333
33333311111111111111111110000d000011dd111111111111111111111111111111111111111111111111111111111111111111111111111111111111333333
33333311111111111111111111111111111111111111111111111111113333333333331111111111111111111133333333333311113333333333331111333333
33333331111111111111111111111111111111111111111111111111133333333333333111111111111111111333333333333331133333333333333113333333
33333333111111111111111111111111111111111111111111111111333333333333333311111111111111113333333333333333333333333333333333333333
33333333111111111111111111111111111111111111111111111111333333333333333311111111511111113333333333333333333333333333333333333333
33333333111111111111111111111111111111111111111111111111333333333333333311111115951111113333333333333333333333333333333333333333
33333333111111111111111111111111111111111111111111111111333333333333333311111159d95111113333333333333333333333333333333333333333
3333333311111111111111111111111111111111111111111111111133333333333333331111159ddd9511113333333333333333333333333333333333333333
333333331111111111111111111111111111111111111111111111113333333333333333111159dd7dd951113333333333333333333333333333333333333333
333333331111111111111111111111111111111111111111111111113333333333333333111159d7eed951113333333333333333333333333333333333333333
333333331111111111111111111111111111111111111111111111113333333333333333111159dee7d951113333333333333333333333333333333333333333
333333331111111111111111111111111111111111111111111111113333333333333333111159dd7dd951113333333333333333333333333333333333333333
3333333311111111111111111111111111111111111111111111111133333333333333331111159ddd9511113333333333333333333333333333333333333333
33333333111111111111111111111111111111111111111111111111333333333333333311111159d95111113333333333333333333333333333333333333333
33333333111111111111111111111111111111111111111111111111333333333333333311111115951111113333333333333333333333333333333333333333
33333331111111111111111111111111111111111111111111111111133333333333333111111111511111111333333333333331133333333333333113333333
33333311111111111111111111111111111111111111111111111111113333333333331111111111111111111133333333333311113333333333331111333333
33333311113333333333331111333333333333111111111111111111111111111111111111111111111111111111111111111111111111111111111111333333
33333331133333333333333113333333333333311111111111111111111111111111111111111111111111111111111111111111111111111111111113333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333333333333333333333333333333333333331111111111111111111111111111111111111111111111111111111111111111111111111111111133333333
33333331133333333333333113333333333333311111111111111111111111111111111111111111111111111111111111111111111111111111111113333333
33333311113333333333331111333333333333111111111111111111111111111111111111111111111111111111111111111111111111111111111111333333
33333311113333333333331111333333333333111133333333333311113333333333331111333333333333111133333333333311113333333333331111333333
33333331133333333333333113333333333333311333333333333331133333333333333113333333333333311333333333333331133333333333333113333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333

__sfx__
00010000336503365033650336501d6501d6501d6501d65028650286502865028650106501065010650106501a6501a6501a6501a6500b6500b6500b6500b6500465004650046500465004650046500465004650
000200003265032650326503265032650326503265024650246502465024650246502465024650246501865018650186501865018650186501865018650186500565005650056500565005650056500565005650
010100002035020350203502035020350203502035020350383503835038350383503835038350383503835022350223502235022350223502235022350223503735037350373503735037350373503735037350
000100003555035550355503555022550225502255022550355503555035550355502255022550225502255035550355503555035550095500955009550095501b5501b5501b5501b55009550095500955009550
00010000095500955009550095502a5502a5502a5502a5500e5500e5500e5500e5502a5502a5502a5502a55017550175501755017550375503755037550375502155021550215502155029550295502955029550
