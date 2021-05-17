const glob = require("glob");
const path = require("path");
const { exec } = require("child_process");
const shell = require("shelljs");

shell.mkdir("./docs/uml");

const outputFolder = "./docs/uml/";
const commandsToRun = [
  `sol2uml ./contracts -i ./contracts/protocol/test/ -f all -v -o ./docs/uml/QuantProtocol.svg`,
];

const executeCommand = (command) =>
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.log(`error: ${error.message}`);
      return;
    }
    if (stderr) {
      console.log(`stderr: ${stderr}`);
      return;
    }
    console.log(`stdout: ${stdout}`);
  });

const addCommandToList = (fullPath) => {
  const fileName = path.basename(fullPath, ".sol");
  const dirName = path.dirname(fullPath);
  shell.mkdir("-p", `./docs/uml/${dirName}`);
  commandsToRun.push(
    `sol2uml ${fullPath} -f png -v -o ${outputFolder}${dirName}/${fileName}.png`
  );
};

glob(
  "contracts/**/*.sol",
  { ignore: "contracts/**/test/*.sol" },
  function (er, files) {
    files.forEach((file) => addCommandToList(file));
    commandsToRun.forEach((command) => executeCommand(command));
  }
);
