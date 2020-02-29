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
const ROLE_NAME = {
  len: "镜音连",
  rin: "镜音铃",
  miku: "初音未来",
  kaito: "Kaito",
  meiko: "Meiko",
  luka: "巡音露卡",
  etc: "其他衍生角色"
};
module.exports = {
  start: 1,
  end: 150,
  outputDir: path.resolve("./", "module"),
  sleep: 500,
  ROLE,
  ROLE_NAME
};
