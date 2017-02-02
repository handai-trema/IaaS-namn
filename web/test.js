var execSync = require('child_process').execSync;
var result;
result =  execSync('bash ./create').toString();
console.log(result);
