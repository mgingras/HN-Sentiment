
###
# Module dependencies.
###

express = require 'express'
routes = require './routes'
user = require './routes/user'
http = require 'http'
path = require 'path'

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


app.get '/', routes.index
app.get '/users', user.list

http.createServer(app).listen app.get('port'), ->
  console.log 'Express server listening on port ' + app.get('port')
