
###
# Module dependencies.
###

express = require 'express'
routes = require './routes'
user = require './routes/user'
http = require 'http'
path = require 'path'
sentiment = require 'sentiment'
twit = require 'twit'

# Express
app = express()

# all environments
app.set 'port', process.env.PORT || 3000
app.set 'views', path.join __dirname, 'views'
app.set 'view engine', 'jade'
app.use express.favicon()
app.use express.json()
app.use express.urlencoded()
app.use express.methodOverride()
app.use app.router
app.use express.static path.join __dirname, 'public'

# development only
if app.get('env') is 'development'
  app.use express.logger 'dev'
  app.use express.errorHandler()
  app.locals.pretty = true



# Twitter Stuff
T = new Twit(
  consumer_key: process.env.consumer_key,
  consumer_secret: process.env.consumer_secret,
  access_token: process.env.oauth_token,
  access_token_secret: process.env.oauth_token_secret
)


# Routes
  app.get '/', routes.index

  http.createServer(app).listen app.get('port'), ->
    console.log 'Express server listening on port ' + app.get('port')
