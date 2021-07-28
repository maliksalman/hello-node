const express = require("express");
const os = require("os");

const app = express();

app.get("/", (req, res, next) => {
    res.json({
        time: new Date(),
        ver: getEnvironmentVar('VER', 'UNKNOWN'),
        host: os.hostname()
    });
});

const port = getEnvironmentVar("SERVER_PORT", 8080);
app.listen(port, () => {
    console.log("Server running: Port=" + port);
}); 

function getEnvironmentVar(varname, defaultvalue)
{
    var result = process.env[varname];
    if(result != undefined) {
        return result;
    } else {
        return defaultvalue;
    }
}