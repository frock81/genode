var http = require('http');
var fs = require('fs');
var nj = require('nunjucks');
const { parse } = require('querystring');

function buildResponse(res, form){
	nj.configure('templates', {autoescape: true});
	console.log('Form:');
	console.log(form);
	console.log('');
	res.writeHead(200, {'Content-server_Type': 'text/html'});
	res.write(nj.render('index.html.njk', form));
	res.end();
}

http.createServer(function (req, res){
	var form = {server_type: "", disks: 0, disk_size: 0};
	if (req.method == 'POST') {
		let body = '';
		req.on('data', (stream) => {
			body += stream.toString();
		});
		req.on('end', () => {
			let bodyObj = parse(body);
			console.log('Form:');
			console.log(form);
			console.log('');

			console.log('bodyObj:');
			console.log(bodyObj);
			console.log('');

			form.server_type = bodyObj.server_type;
			form.disks = bodyObj.disks;
			form.disk_size = bodyObj.disk_size;

			buildResponse(res, form);
		});
	} else if (req.method == 'GET') {
		buildResponse(res, form);
	}
}).listen(8080);