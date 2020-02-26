const readFileTree = require("read-file-tree");
const fs = require("fs");
const path = require("path");
const config = require("../.vuepress/config");

const basePath = "module";
const outputPath = "list";

const tree = readFileTree.sync(basePath);

const categories = Object.keys(tree)
  .filter(categoryName => categoryName !== ".gitkeep")
  .map(categoryName => {
    const category = tree[categoryName];
    const modules = Object.keys(category).map(moduleName => ({
      name: moduleName,
      pic: "index.jpg"
    }));
    return {
      name: categoryName,
      modules
    };
  });

/**
 * 删除老的文件
 */
if (!fs.existsSync(outputPath)) {
  fs.mkdirSync(outputPath);
}
const oldFiles = fs.readdirSync(outputPath);
for (file of oldFiles) {
  fs.unlinkSync(path.resolve(outputPath, file));
}

/** 增加list文件 */
categories.forEach(({ name, modules }) => {
  fs.writeFileSync(
    path.resolve(outputPath, `${name}.md`),
    `
# ${name}
模组：

${modules
  .map(
    _module =>
      `![${_module.name}](../module/${[name, _module.name, _module.pic].join(
        "/"
      )})  
      模组主页：[点击前往](${config.base}module/${name}/${_module.name})
      `
  )
  .join("\n")}
  `,
    {
      flag: "w"
    }
  );
});

fs.writeFileSync(
  path.resolve(outputPath, "README.md"),
  `
# 根据分类查看
${categories
  .map(
    ({ name }) => `
# ${name}
[点击前往](${config.base}list/${name})
`
  )
  .join("\n")}
`,
  {
    flag: "w"
  }
);

// 输出顶部控制
fs.writeFileSync(
  path.resolve(".vuepress/nav.json"),
  JSON.stringify(
    categories.map(({ name }) => ({
      text: name,
      link: `/list/${name}`
    })),
    null,
    2
  ),
  { flag: "w" }
);
