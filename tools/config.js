const path = require("path");
const ROLE = {
  MIKU: "miku",
  RIN: "rin",
  LEN: "len",
  LUKA: "luka",
  MEIKO: "meiko",
  KAITO: "kaito",
  OTHER: "etc"
};
module.exports = {
  start: 1,
  end: 150,
  outputDir: path.resolve("./", "module"),
  sleep: 500,
  ROLE
};
