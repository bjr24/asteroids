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
score = 0
numFireFlowersPickedUp = 0

onLoad = ->
    imgBaseUrl = ""
    images = new ImageLoader [
        { name: "asteroid", url: imgBaseUrl + "asteroid-img.png" }
        { name: "ship-thrust", url: imgBaseUrl + "spaceship-thrust.gif" }
        { name: "ship", url: imgBaseUrl + "spaceship-no-thrust.gif" }
        { name: "mushroom", url: imgBaseUrl + "mushroom.png" }
        { name: "fireflower", url: imgBaseUrl + "fireflower.gif" }
        { name: "fireball", url: imgBaseUrl + "fireball.png" }
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
    setInterval (->
        powerUps.push(new FireFlower())
    ), 30000

    stars.push(new Star()) for i in [0...30]

    setInterval(draw, fpsToInterval(frameRate))
    bindControls(ship)
    $("#gameCanvas").click (evt) ->
        x = evt.offsetX
        y = evt.offsetY
        dx = x - ship.x
        dy = y - ship.y
        ship.heading = Math.atan2(-dy, dx)
        ship.shoot()
    #setInterval(ship.randomMove, 200)


draw = ->
    drawBackground()
    ship.draw()
    bullets = bullets.filter (b) ->
        b.exists()
    b.draw() for b in bullets

    asteroids = asteroids.filter (a) ->
        a.exists()
    $("#asteroidCount").text(asteroids.length)
    a.draw() for a in asteroids

    powerUps = powerUps.filter (p) -> p.exists()
    p.draw() for p in powerUps

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


class Drawable
    constructor: (@x, @y) ->
        @x ?= Math.randInt(canvasWidth)
        @y ?= Math.randInt(canvasHeight)
        @xForce = 0
        @yForce = 0
        @heading = Math.PI / 2
        @rotation = @heading
        @headingMatchesRotation = true
        @drag = 0

    draw: =>
        @update(fpsToInterval(frameRate))
        xformCanvas (c) =>
            c.translate(@x, @y)
            rot = if @headingMatchesRotation then @heading else @rotation
            c.rotate(-rot + Math.PI / 2)
            @render(c)

    update: (dt) =>
        @xForce -= @drag * @xForce
        @yForce -= @drag * @yForce
        newX = @x + @xForce * dt * updateCoefficient
        newY = @y + @yForce * dt * updateCoefficient
        dx = newX - @x
        dy = newY - @y
        distance = dx * dx + dy * dy
        @x = newX
        @y = newY
        @x %= canvasWidth
        @y %= canvasHeight
        @x += canvasWidth if @x < 0
        @y += canvasHeight if @y < 0
        distance


    applyForce: (magnitude) =>
        @xForce += Math.cos(@heading) * magnitude
        @yForce -= Math.sin(@heading) * magnitude


    checkCollision: (otherItems) =>
        for e in otherItems when @closeEnough(e)
            return true
        return false

    closeEnough: (other, dist = 25) =>
        dx = @x - other.x
        dy = @y - other.y
        dx * dx + dy * dy < dist * dist


class Ship extends Drawable

    constructor: ->
        @image = images.get("ship")
        @width = @image.width * .5
        @height = @image.height * .5
        @thrustImg = images.get("ship-thrust")

        @x = canvasWidth / 2
        @y = canvasHeight / 2
        super(@x, @y)

        @drag = .01
        @recovering = false
        @thrustVisible = false

    render: (c) ->
        if @recovering
            c.globalAlpha = .4
        img = if @thrustVisible then @thrustImg else @image
        c.drawImage(img, -@width / 2, -@height / 2, @width, @height)

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
        @checkAsteroidCollision()
        @checkPowerUpPickup()

    checkAsteroidCollision: =>
        if (asteroids.some (a) => @closeEnough(a, a.radius))
            healthBar.decrement()
            @recovering = true
            @thrustVisibility(false)
            setTimeout (=>
                @recovering = false
            ), 2000

    checkPowerUpPickup: =>
        for p in powerUps when @closeEnough(p, @height)
            healthBar.increment()
            p.pickedUp = true
            p.onPickup()

    thrustVisibility: (val) =>
        @thrustVisible = val and not @recovering


class HealthBar

    height = 15
    constructor: (@maxHealth) ->
        @x = 0
        @y = canvasHeight - height
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
            c.fillRect(@x, @y, @width, height)




class Asteroid extends Drawable

    scoreTable =
        3: 20
        2: 50
        1: 100

    constructor: (@size = 3, parent = null, hitter = null, first = false) ->
        @image = images.get("asteroid")

        @radius = (@size / 6 * @image.width) / 2
        @xForce = 0
        @yForce = 0
        if parent?
            @x = parent.x
            @y = parent.y
            super(@x, @y)
            @heading = hitter.heading + (if first then .2 else -0.2)
        else
            @x = Math.randInt(canvasWidth)
            @y = Math.randInt(canvasHeight)
            super(@x, @y)
            @heading = Math.random() * Math.PI * 2

        @applyForce(.1)
        @gotHit = false

    render: (c) =>
        c.drawImage(@image, -@radius, -@radius, @radius * 2, @radius * 2)

    exists: =>
        not @gotHit

    update: =>
        super
        hitter = null
        for b in bullets when @closeEnough(b, b.width + @radius)
            b.onHit()
            hitter = b
            @gotHit = true
        if @gotHit
            score += scoreTable[@size]
            $("#scoreDisplay").text(score)
            if @size > 1
                asteroids.push(new Asteroid(@size - 1, @, hitter, false))
                asteroids.push(new Asteroid(@size - 1, @, hitter, true))


class Bullet extends Drawable
    constructor: (ship) ->
        @x = ship.x
        @y = ship.y
        super(@x, @y)
        @xForce = ship.xForce
        @yForce = ship.yForce
        @heading = ship.heading
        @distanceRemaining = 3000
        @height = 25
        @width = 10
        @applyForce(thrust / 20)

    render: (c) =>
        c.fillStyle = "#FF0000"
        c.fillRect(-@width / 2, -@height / 2 , @width, @height)

    update: => @distanceRemaining -= super

    exists: => @distanceRemaining > 0

    onHit: => @distanceRemaining = -1


class FireBall extends Drawable
    sizes =
        3: 32
        2: 25
        1: 20

    constructor: (parent, @size = 3, nthChild = 0) ->
        @x = parent.x
        @y = parent.y
        super(@x, @y)

        @image = images.get("fireball")
        if @size is 3
            @heading = parent.heading
            @xForce = parent.xForce
            @yForce = parent.yForce
            @applyForce(thrust / 20)
        else
            @heading += Math.PI / 4 if @size is 1
            @heading += Math.PI / 2 * nthChild
            @applyForce(.1)

        @hit = false
        @distanceRemaining = 10000

        @width = sizes[@size]
        scaling = @width / @image.width
        @height = @image.height * scaling


    render: (c) =>
        c.drawImage(@image, -@width / 2, -@height / 2, @width, @height)

    update: => @distanceRemaining -= super

    exists: =>
        return false if @hit
        return true if @size is 3
        return @distanceRemaining > 0

    onHit: =>
        @hit = true
        return if @size is 1
        bullets.push(new FireBall(@, @size - 1, i)) for i in [0...4]


class PowerUp extends Drawable
    constructor: (imgName) ->
        @image = images.get(imgName)
        @setWidth(75)
        super(null, null)
        @headingMatchesRotation = false
        @heading = Math.random() * 2 * Math.PI
        @applyForce(.05)
        @pickedUp = false
        @createTimeMs = new Date().getTime()

    render: (c) =>
        c.drawImage(@image, -@width / 2, -@height / 2, @width, @height)

    lifetimeExceeded: () ->
        (new Date().getTime() - @createTimeMs) > 100000

    exists: =>
        not @pickedUp and not @lifetimeExceeded()

    setWidth: (width) =>
        @width = width
        scaling = @width / @image.width
        @height = @image.height * scaling



class Mushroom extends PowerUp
    constructor: ->
        super "mushroom"

    onPickup: -> healthBar.increment()


class FireFlower extends PowerUp
    constructor: ->
        super "fireflower"
        @setWidth(120)

    onPickup: -> numFireFlowersPickedUp += 1


class Star extends Drawable

    render: (c) =>
        c.fillStyle = "#FFFFFF"
        c.fillRect(0, -1, 1, 3)
        c.fillRect(-1, 1, 3, 1)


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
        @x += other.x
        @y += other.y

    mult: (other) =>
        @x *= other.x
        @y *= other.y

$ ->
    onLoad()




