
canvas = null
canvasWidth = 0
canvasHeight = 0
imageScaleScaleFactor = .5
frameRate = 20
thrust = 5
updateCoefficient = 1

ship = null
bullets = []
asteroids = []

gameInit = ->
  canvas = $("#gameCanvas")[0].getContext("2d")
  canvasWidth = $("#gameCanvas").width()
  canvasHeight = $("#gameCanvas").height()
  ship = new Ship()

  asteroids.push(new Asteroid())
  setInterval((-> asteroids.push(new Asteroid())), 5000)

  setInterval(draw, fpsToInterval(frameRate))
  bindControls(ship)
  #setInterval(ship.randomMove, 200)

draw = ->
  canvas.clearRect(0, 0, canvasWidth, canvasHeight)
  ship.draw()
  bullets = bullets.filter (b) -> b.exists()
  b.draw() for b in bullets

  asteroids = asteroids.filter (a) -> a.exists()
  a.draw() for a in asteroids

fpsToInterval = (fps) ->
  1000 / fps





bindControls = (ship) ->
  keyIntervalIds = { }

  window.onkeydown = (evt) ->
    return if keyIntervalIds[evt.keyCode]?
    action = switch evt.keyCode
      # y
      when 90 then ship.rotateLeft
      # x
      when 88 then ship.rotateRight
      # comma
      when 188 then ship.applyThrust

    keyIntervalIds[evt.keyCode] = setInterval(action, 50)

  window.onkeyup = (evt) ->
    clearInterval(keyIntervalIds[evt.keyCode])
    keyIntervalIds[evt.keyCode] = null

  window.onkeypress = (evt) ->
    ship.shoot() if evt.charCode is 46 # '.'


class Drawable
  draw: =>
    @update(fpsToInterval(frameRate))
    canvas.save()
    canvas.translate(@x, @y)
    canvas.rotate(-@heading + Math.PI / 2)
    @render()
    canvas.restore()

  update: (dt) =>
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


  loadImage: (src, scale = imageScaleScaleFactor) =>
    image = new Image()
    image.onload = =>
      @width = image.width * scale
      @height = image.height * scale
      @drawImage = =>
        canvas.drawImage(image, -@width / 2, -@height / 2, @width, @height)
    image.src = src

  checkCollision: (otherItems) =>
    for e in otherItems when @closeEnough(e)
      return true
    return false

  closeEnough: (other, distSquared = 600) =>
    dx = @x - other.x
    dy = @y - other.y
    dx * dx + dy * dy < distSquared


class Ship extends Drawable
  constructor: ->
    @width = 0
    @length = 0
    image = new Image()
    image.onload = =>
      @width = image.width * imageScaleScaleFactor
      @height = image.height * imageScaleScaleFactor
      @drawImage = =>
        canvas.drawImage(image, -@width / 2, -@height / 2, @width, @height)
    image.src = "spaceship.gif"
    @setInitialPosition()

  setInitialPosition: =>
    @x = canvasWidth / 2
    @y = canvasHeight / 2
    @xForce = 0
    @yForce = 0
    @heading = Math.PI / 2


  render: =>
    @drawImage()

  applyThrust: =>
    @applyForce(thrust / 1000)

  rotateSize = .3

  rotateLeft: =>
    @heading += rotateSize

  rotateRight: =>
    @heading -= rotateSize

  shoot: =>
    bullets.push(new Bullet(@))

  randomMove: =>
    moves = [@applyThrust, @rotateLeft, @rotateRight, @shoot]
    moves[Math.randInt(moves.length)]()



class Asteroid extends Drawable
  image = new Image()
  image.onload = =>
    @drawImage = (scaling) =>
      canvas.drawImage(image, -@width / 2, -@height / 2, @width, @height)
  image.src = "asteroid-img.png"

  constructor: (@size = 2, parent = null, first = false) ->
    @width = @size / 4 * image.width
    @height = @size / 4 * image.height
    @length = @height
    @xForce = 0
    @yForce = 0
    @loadImage("asteroid-img.png", @size / 4)
    if (parent?)
      @x = parent.x
      @y = parent.y
      @heading = parent.heading + (if first then .2 else -0.2)
    else
      @x = Math.randInt(canvasWidth)
      @y = Math.randInt(canvasHeight)
      @heading = Math.random() * Math.PI * 2

    @applyForce(.1)
    @gotHit = false

  render: =>
    @drawImage()

  exists: =>
    not @gotHit

  update: (dt) =>
    super dt
    for b in bullets when @closeEnough(b)
      b.exists(false)
      @gotHit = true
    if @gotHit and @size > 1
      asteroids.push(new Asteroid(1, @, false))
      asteroids.push(new Asteroid(1, @, true))



class Bullet extends Drawable
  constructor: (ship) ->
    @x = ship.x
    @y = ship.y
    @xForce = ship.xForce
    @yForce = ship.yForce
    @heading = ship.heading
    @distanceRemaining = 50 * 60
    @length = 25
    @width = 10
    @applyForce(thrust / 20)

  render: =>
    canvas.fillStyle = "#FF0000"
    canvas.fillRect(-@width / 2, -@length - 10, @width, @length)

  update: (dt) =>
    @distanceRemaining -= super

  exists: (val = true) =>
    @distanceRemaining = -1 unless val
    @distanceRemaining > 0






Math.randInt = (a, b = null) ->
  [a, b] = [0, a] if not b?
  range = b - a
  a + Math.floor(Math.random() * range)



$ -> gameInit()




