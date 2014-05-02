canvas = null
canvasWidth = 0
canvasHeight = 0
frameRate = 20
thrust = 5
updateCoefficient = 1
images = null

ship = null
bullets = []
asteroids = []
stars = []
healthBar = null
powerUps = []
coins = []
score = 0
hits = 0
numFireFlowersPickedUp = 0

onLoad = ->
    imgBaseUrl = ""
    images = new ImageLoader [
        { name: "asteroid", url: imgBaseUrl + "img/asteroid-img.png" }
        { name: "ship-thrust", url: imgBaseUrl + "img/spaceship-thrust.gif" }
        { name: "ship", url: imgBaseUrl + "img/spaceship-no-thrust.gif" }
        { name: "mushroom", url: imgBaseUrl + "img/mushroom.png" }
        { name: "fireflower", url: imgBaseUrl + "img/fireflower.gif" }
        { name: "fireball", url: imgBaseUrl + "img/fireball.png" }
        { name: "star", url: imgBaseUrl + "img/star.png" }
        { name: "invin1", url: imgBaseUrl + "img/invincible-ship/ship1.gif" }
        { name: "invin2", url: imgBaseUrl + "img/invincible-ship/ship2.gif" }
        { name: "invin3", url: imgBaseUrl + "img/invincible-ship/ship3.gif" }
        { name: "invin4", url: imgBaseUrl + "img/invincible-ship/ship4.gif" }
        { name: "invin5", url: imgBaseUrl + "img/invincible-ship/ship5.gif" }
        { name: "green-shell", url: imgBaseUrl + "img/green-shell.png" }
        { name: "coin", url: imgBaseUrl + "img/coin.png" }

    ]
    images.onLoad(gameInit)
    canvas = $("#gameCanvas")[0].getContext("2d")
    canvasWidth = $("#gameCanvas").width()
    canvasHeight = $("#gameCanvas").height()


gameInit = ->
    healthBar = new HealthBar(10)
    ship = new Ship()

    asteroids.push(new Asteroid())
    #asteroids.push(new Asteroid()) for i in [0...100]
    setInterval (->
        asteroids.push(new Asteroid())
    ), 5000


    powerUps.push(new Mushroom())
    powerUps.push(new FireFlower())
    powerUps.push(new StarPowerUp())
    setInterval(spawnPowerup, 30000)


    stars.push(new Star()) for i in [0...30]

    setInterval(draw, fpsToInterval(frameRate))
    bindControls(ship)
    $("#gameCanvas").click (evt) ->
        clickPos = new Vec2(evt.offsetX, evt.offsetY)
        diff = clickPos.sub(ship.position)
        ship.heading = Math.atan2(-diff.y, diff.x)
        ship.shoot()
    $("#flower-btn").click -> new FireFlower().onPickup()
    $("#mushroom-btn").click -> new Mushroom().onPickup()
    $("#star-btn").click -> new StarPowerUp().onPickup()
    #setInterval(ship.randomMove, 200)


draw = ->
    drawBackground()
    ship.draw()

    bullets = bullets.filter (b) -> b.exists()
    b.draw() for b in bullets

    asteroids = asteroids.filter (a) -> a.exists()
    $("#asteroidCount").text(asteroids.length)
    a.draw() for a in asteroids

    powerUps = powerUps.filter (p) -> p.exists()
    p.draw() for p in powerUps

    coins = coins.filter (c) -> c.exists()
    c.draw() for c in coins

    healthBar.draw()



drawBackground = ->
    xformCanvas (c) =>
        c.fillStyle = "#000000"
        c.fillRect(0, 0, canvasWidth, canvasHeight)
    s.draw() for s in stars


xformCanvas = (fn) ->
    canvas.save()
    try
        fn(canvas)
    finally
        canvas.restore()


fpsToInterval = (fps) ->
    1000 / fps


bindControls = (ship) ->
    keyIntervalIds = {}

    window.onkeydown = (evt) ->
        return if keyIntervalIds[evt.keyCode]?
        action = switch evt.keyCode
        # left arrow key
            when 37, 90 then ship.rotateLeft
        # right arrow key
            when 39, 88 then ship.rotateRight
        # up arrow key
            when 38, 188
                ship.thrustVisibility(true)
                ship.applyThrust

        keyIntervalIds[evt.keyCode] = setInterval(action, 50)

    window.onkeyup = (evt) ->
        keyCode = evt.keyCode
        clearInterval(keyIntervalIds[keyCode])
        keyIntervalIds[keyCode] = null
        ship.thrustVisibility(false) if keyCode is 38 or keyCode is 188

    window.onkeypress = (evt) ->
        #spacebar
        if evt.keyCode is 32 or evt.keyCode is 46
            evt.preventDefault()
            ship.shoot()


powerUpCounter = 0
spawnPowerup = () ->
    powerUp = switch powerUpCounter
        when 0 then new Mushroom()
        when 1 then new FireFlower()
        when 2 then new StarPowerUp()
    powerUps.push(powerUp)
    powerUpCounter = (powerUpCounter + 1) % 3




class Drawable
    constructor: (x, y) ->
        x ?= Math.randInt(canvasWidth)
        y ?= Math.randInt(canvasHeight)
        @position = new Vec2(x, y)
        @force = new Vec2(0, 0)
        @heading = Math.PI / 2
        @rotation = @heading
        @headingMatchesRotation = true
        @drag = 1

    draw: =>
        @update(fpsToInterval(frameRate))
        xformCanvas (c) =>
            c.translate(@position.x, @position.y)
            rot = if @headingMatchesRotation then @heading else @rotation
            c.rotate(-rot + Math.PI / 2)
            @render(c)

    drawImage: (c, image) =>
        c.drawImage(image, -@size.x / 2, -@size.y / 2, @size.x, @size.y)

    update: (dt) =>
        @force = @force.scale(@drag)

        newPos = @force.scale(dt * updateCoefficient).add(@position)

        distance = @position.dist(newPos)
        @position = newPos.wrap()

        return distance


    applyForce: (magnitude) =>
        @force = @force.addPolar(magnitude, @heading)


    closeEnough: (other, dist = 25) =>
        @position.withinDist(other.position, dist)


class Ship extends Drawable

    constructor: ->
        @image = images.get("ship")
        @size = new Vec2(@image.width, @image.height).scale(.5)
        @thrustImg = images.get("ship-thrust")
        @invinImgs = [
            images.get("invin1")
            images.get("invin2")
            images.get("invin3")
            images.get("invin4")
            images.get("invin5")
        ]
        @invinCount = 0
        @isInvin = false
        @invinAlmostOver = false

        super(canvasWidth / 2, canvasHeight / 2)

        @drag = .99
        @recovering = false
        @thrustVisible = false

    render: (c) ->
        if @recovering or @invinAlmostOver
            c.globalAlpha = .4
        if @isInvin and not @invinAlmostOver
            img = @invinImgs[@invinCount]
            @invinCount = (@invinCount + 1) % 5
        else
            img = if @thrustVisible then @thrustImg else @image
        @drawImage(c, img)

    applyThrust: =>
        @applyForce(thrust / 1000) unless @recovering

    rotateSize = .3

    rotateLeft: =>
        @heading += rotateSize unless @recovering

    rotateRight: =>
        @heading -= rotateSize unless @recovering

    shoot: =>
        return if @recovering
        if numFireFlowersPickedUp > 0
            bullets.push(new FireBall(@))
            numFireFlowersPickedUp -= 1
        else
            bullets.push(new Bullet(@))


    randomMove: =>
        moves = [@applyThrust, @rotateLeft, @rotateRight, @shoot]
        moves[Math.randInt(moves.length)]()

    update: =>
        super
        return if @recovering
        if @isInvin
            @checkInvinAsteroidCollision()
        else
            @checkAnyAsteroidCollision()
        @checkPowerUpPickup()
        @checkCoinPickup()

    checkAnyAsteroidCollision: =>
        if (asteroids.some (a) => @closeEnough(a, a.size.x))
            healthBar.decrement()
            @recovering = true
            @thrustVisibility(false)
            setTimeout (=>
                @recovering = false
            ), 2000

    checkInvinAsteroidCollision: =>
        a.onHit(@) for a in asteroids when @closeEnough(a, a.size.x)

    checkPowerUpPickup: =>
        for p in powerUps when @closeEnough(p, @height)
            #healthBar.increment()
            p.pickedUp = true
            p.onPickup()

    checkCoinPickup: =>
        for c in coins when @closeEnough(c, @height)
            c.onPickup()

    thrustVisibility: (val) =>
        @thrustVisible = val and not @recovering

    setInvin: (val) =>
        @isInvin = val
        @recovering = false
        @invinAlmostOver = false






class HealthBar

    height = 15
    constructor: (@maxHealth) ->
        @position = new Vec2(0, canvasHeight - height)
        @setHealthLeft(@maxHealth)

    setHealthLeft: (health) =>
        @health = health
        @width = canvasWidth * health / @maxHealth

    decrement: =>
        @setHealthLeft(@health - 1)

    increment: =>
        return unless @health < @maxHealth
        @setHealthLeft(@health + 1)

    draw: =>
        xformCanvas (c) =>
            c.fillStyle = "#00FF00"
            c.fillRect(@position.x, @position.y, @width, height)




class Asteroid extends Drawable

    scoreTable =
        1: 30
        2: 20
        3: 10

    sizeTable =
        1: 30
        2: 50
        3: 70

    constructor: (@type = 3, parent = null, hitter = null, first = false) ->
        #@image = images.get("asteroid")
        @image = images.get("green-shell")
        #@size = new Vec2(@image.width, @image.height).scale(@type / 6)
        @size = new Vec2(@image.width, @image.height).scaleToWidth(sizeTable[@type])
        @force = new Vec2(0, 0)
        if parent?
            super(parent.position.x, parent.position.y)
            @heading = hitter.heading + (if first then .2 else -0.2)
        else
            super(Math.randInt(canvasWidth), Math.randInt(canvasHeight))
            @heading = Math.random() * Math.PI * 2

        @headingMatchesRotation = false
        @rotation = Math.PI / 2
        @applyForce(.1)
        @gotHit = false

    render: (c) =>
        @drawImage(c, @image)

    exists: =>
        not @gotHit

    update: =>
        super
        hitter = null
        for b in bullets when @closeEnough(b, @size.x)
            b.onHit()
            hitter = b
            @gotHit = true
        @onHit(hitter) if @gotHit

    onHit: (hitter) =>
        @gotHit = true
        score += scoreTable[@type]
        $("#scoreDisplay").text(score)
        hits += 1
        $("#hitsDisplay").text(hits)
        if @type > 1
            asteroids.push(new Asteroid(@type - 1, @, hitter, false))
            asteroids.push(new Asteroid(@type - 1, @, hitter, true))
        else
            coins.push(new Coin(@))



class Bullet extends Drawable
    constructor: (ship) ->
        super(ship.position.x, ship.position.y)
        @force = ship.force.copy()
        @heading = ship.heading
        @distanceRemaining = 3000
        @size = new Vec2(10, 25)
        @applyForce(thrust / 20)

    render: (c) =>
        c.fillStyle = "#FF0000"
        c.fillRect(-@size.x / 2, -@size.y / 2 , @size.x, @size.y)

    update: => @distanceRemaining -= super

    exists: => @distanceRemaining > 0

    onHit: => @distanceRemaining = -1


class FireBall extends Drawable
    sizes =
        3: 32
        2: 25
        1: 20

    constructor: (parent, @type = 3, nthChild = 0) ->
        super(parent.position.x, parent.position.y)

        @image = images.get("fireball")
        if @type is 3
            @heading = parent.heading
            @force = parent.force.copy()
            @applyForce(thrust / 20)
        else
            @heading += Math.PI / 4 if @type is 1
            @heading += Math.PI / 2 * nthChild
            @applyForce(.1)

        @hit = false
        @distanceRemaining = 10000

        @size = new Vec2(@image.width, @image.height).scaleToWidth(sizes[@type])
        @createTimeMs = new Date().getTime()



    render: (c) =>
        @drawImage(c, @image)

    update: => @distanceRemaining -= super

    exists: =>
        return false if @hit
        return true if @type is 3
        return @distanceRemaining > 0

    onHit: =>
        return if (new Date().getTime() - @createTimeMs) < 500
        @hit = true
        return if @type is 1
        bullets.push(new FireBall(@, @type - 1, i)) for i in [0...4]


class PowerUp extends Drawable
    constructor: (imgName) ->
        @image = images.get(imgName)
        @size = new Vec2(@image.width, @image.height)
        super(null, null)
        @headingMatchesRotation = false
        @heading = Math.random() * 2 * Math.PI
        @applyForce(.05)
        @pickedUp = false
        @createTimeMs = new Date().getTime()

    render: (c) =>
        @drawImage(c, @image)

    lifetimeExceeded: () ->
        (new Date().getTime() - @createTimeMs) > 10000

    exists: =>
        not @pickedUp and not @lifetimeExceeded()



class Mushroom extends PowerUp
    constructor: ->
        super("mushroom")
        @size = @size.scaleToWidth(75)

    onPickup: -> healthBar.increment()


class FireFlower extends PowerUp
    constructor: ->
        super("fireflower")
        @size = @size.scaleToWidth(120)

    onPickup: -> numFireFlowersPickedUp += 1


class StarPowerUp extends PowerUp
    constructor: ->
        super("star")
        @size = @size.scaleToWidth(38)

    onPickup: ->
        ship.setInvin(true)
        setTimeout ( ->
            ship.invinAlmostOver = true
        ), 20000

        setTimeout ( ->
            ship.setInvin(false)
        ), 25000


class Star extends Drawable
    render: (c) =>
        c.fillStyle = "#FFFFFF"
        c.fillRect(0, -1, 1, 3)
        c.fillRect(-1, 1, 3, 1)


class Coin extends Drawable
    constructor: (parent) ->
        super(parent.position.x, parent.position.y)
        @image = images.get("coin")
        @size = new Vec2(@image.width, @image.height).scaleToWidth(25)
        @pickedUp = false

    render: (c) =>
        @drawImage(c, @image)

    onPickup: =>
        @pickedUp = true
        score += 10
        $("#scoreDisplay").text(score)

    exists: =>
        not @pickedUp

Math.randInt = (a, b = null) ->
    [a, b] = [0, a] if not b?
    range = b - a
    a + Math.floor(Math.random() * range)

class ImageLoader
    constructor: (@imageReqs) ->
        @imageMap = {}
        @numLoaded = 0
        @totalNumImages = @imageReqs.length
        for req in @imageReqs
            image = new Image()
            image.onload = => @numLoaded += 1
            image.src = req.url
            @imageMap[req.name] = image

    onLoad: (callBack) =>
        if @numLoaded < @totalNumImages
            setTimeout (=>
                @onLoad(callBack)
            ), 10
            return
        callBack()

    get: (name) => @imageMap[name]


class Vec2
    constructor: (@x = 0, @y = 0) ->


    add: (other) =>
        new Vec2(@x + other.x, @y + other.y)

    sub: (other) =>
        @add(other.scale(-1))

    dotProd: (other) =>
        new Vec2(@x * other.x, @y * other.y)

    scale: (val) =>
        new Vec2(@x * val, @y * val)

    scaleToWidth: (newWidth) =>
        @scale(newWidth / @x)

    dist: (other) =>
        delta = @sub(other)
        product = delta.dotProd(delta)
        product.x + product.y

    wrap: =>
        x = @x % canvasWidth
        y = @y % canvasHeight
        x += canvasWidth if @x < 0
        y += canvasHeight if @y < 0
        new Vec2(x, y)

    withinDist: (other, dist) =>
        @dist(other) < (dist * dist)


    addPolar: (r, theta) =>
        x = Math.cos(theta) * r + @x
        y = -Math.sin(theta) * r + @y
        new Vec2(x, y)

    copy: =>
        new Vec2(@x, @y)

$ ->
    onLoad()




