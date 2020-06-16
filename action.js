const core = require('@actions/core')
const exec = require('@actions/exec')
const os = require("os");

try {
    let target = core.getInput('target')
    console.log(target)

} catch (error) {
    setFailed(error)
}
