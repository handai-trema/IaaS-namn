var http = require('http');

function getIP(request) {
  if (request.headers['x-forwarded-for']){
    return request.headers['x-forwarded-for'];
  }
  if (request.connection && request.connection.remoteAddress){
    return request.connection.remoteAddress;
  }
  if (request.connection.socket && request.connection.socket.remoteAddress){
    return request.connection.socket.remoteAddress;
  }
  if (request.socket && request.socket.remoteAddress){
    return request.socket.remoteAddress;
  }
  return '0.0.0.0';
}

function start(){
  function onRequest(request, response){

    console.log("request received\n")
    var execSync = require('child_process').execSync;
    var guestIP = getIP(request).substr(7);
    var result = execSync('bash ./create ' + guestIP).toString();
    //var result = guestIP;
    if(result != ""){
      response.writeHead(200, {'Content-Type': 'text/plain'});
      response.write(result);
      //response.writeHead(403);
    }else{
      response.writeHead(403);
    }
    response.end();

  }
  http.createServer(onRequest).listen(8124);
  console.log('Server running at http://127.0.0.1:8124/');
}

exports.start = start;
