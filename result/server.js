var express = require('express'),
  async = require('async'),
  pg = require('pg'),
  path = require('path'),
  cookieParser = require('cookie-parser'),
  methodOverride = require('method-override'),
  app = express(),
  server = require('http').Server(app),
  io = require('socket.io')(server, {
    transports: ['polling']
  });

var port = process.env.PORT || 4000;

// ---------------------------------------------------------------------------
// DbReadCircuitBreaker – «pattern: Circuit Breaker»
// States: CLOSED (normal) → OPEN (failing) → HALF-OPEN (probing)
// ---------------------------------------------------------------------------
class DbReadCircuitBreaker {
  constructor({ failureThreshold = 5, successThreshold = 2, openTimeout = 10000 } = {}) {
    this.state = 'CLOSED';
    this.failureCount = 0;
    this.successCount = 0;
    this.failureThreshold = failureThreshold;
    this.successThreshold = successThreshold;
    this.openTimeout = openTimeout;
    this.lastFailureTime = null;
  }

  async call(fn) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.openTimeout) {
        this.state = 'HALF-OPEN';
        this.successCount = 0;
        this.failureCount = 0;
        console.log('[CircuitBreaker] State: HALF-OPEN (probing)');
      } else {
        throw new Error('Circuit breaker is OPEN – call rejected');
      }
    }

    try {
      const result = await fn();
      this._onSuccess();
      return result;
    } catch (err) {
      this._onFailure();
      throw err;
    }
  }

  _onSuccess() {
    if (this.state === 'HALF-OPEN') {
      this.successCount++;
      if (this.successCount >= this.successThreshold) {
        this.state = 'CLOSED';
        this.failureCount = 0;
        console.log('[CircuitBreaker] State: CLOSED (recovered)');
      }
    } else {
      this.failureCount = 0;
    }
  }

  _onFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    if (this.state === 'HALF-OPEN') {
      this.state = 'OPEN';
      console.log('[CircuitBreaker] State: OPEN (half-open probe failed)');
    } else if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
      console.log(`[CircuitBreaker] State: OPEN after ${this.failureCount} failures`);
    }
  }
}

var circuitBreaker = new DbReadCircuitBreaker({
  failureThreshold: 5,
  successThreshold: 2,
  openTimeout: 10000
});

// ---------------------------------------------------------------------------
// ResultsDbReader – actual DB read through the circuit breaker
// ---------------------------------------------------------------------------
function resultsDbReader(client) {
  return new Promise((resolve, reject) => {
    client.query(
      'SELECT vote, COUNT(id) AS count FROM votes GROUP BY vote',
      [],
      function (err, result) {
        if (err) reject(err);
        else resolve(result);
      }
    );
  });
}

// ---------------------------------------------------------------------------

io.sockets.on('connection', function (socket) {
  socket.emit('message', { text: 'Welcome!' });

  socket.on('subscribe', function (data) {
    socket.join(data.channel);
  });
});

var pool = new pg.Pool({
  connectionString: 'postgres://okteto:okteto@postgresql/votes',
});

async.retry(
  { times: 1000, interval: 1000 },
  function (callback) {
    pool.connect(function (err, client, done) {
      if (err) {
        console.error('Waiting for db', err);
      }
      callback(err, client);
    });
  },
  function (err, client) {
    if (err) {
      console.error('Giving up');
      return;
    }
    console.log('Connected to db');
    getVotes(client);
  }
);

// ResultsPollingService → ResultsQueryServer → DbReadCircuitBreaker → ResultsDbReader
function getVotes(client) {
  circuitBreaker.call(() => resultsDbReader(client))
    .then(function (result) {
      var votes = collectVotesFromResult(result);
      io.sockets.emit('scores', JSON.stringify(votes));
    })
    .catch(function (err) {
      console.error('[CircuitBreaker] Query failed: ' + err.message);
    })
    .finally(function () {
      setTimeout(function () {
        getVotes(client);
      }, 1000);
    });
}

function collectVotesFromResult(result) {
  var votes = { a: 0, b: 0 };

  result.rows.forEach(function (row) {
    votes[row.vote] = parseInt(row.count);
  });

  return votes;
}

app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));
app.use(methodOverride('X-HTTP-Method-Override'));
app.use(function (req, res, next) {
  res.header('Access-Control-Allow-Origin', '*');
  res.header(
    'Access-Control-Allow-Headers',
    'Origin, X-Requested-With, Content-Type, Accept'
  );
  res.header('Access-Control-Allow-Methods', 'PUT, GET, POST, DELETE, OPTIONS');
  next();
});

app.use(express.static(__dirname + '/views'));

app.get('/', function (req, res) {
  res.sendFile(path.resolve(__dirname + '/views/index.html'));
});

server.listen(port, function () {
  var port = server.address().port;
  console.log('App running on port ' + port);
});
