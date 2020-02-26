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
<div class="row">
${modules
  .map(_module => {
    const pic = `../module/${[name, _module.name, _module.pic].join("/")}`;
    return `<div class="col-sm-24 col-md-6 col-lg-6 col-xl-4" style="margin-bottom: 15px;">
      <a style="text-align: center;" href="${config.base}module/${name}/${_module.name}">
        <img src="${pic}" />
        <div>${_module.name}</div>
        <div>点击前往</div>
      </a>
    </div>`;
  })
  .join("\n")}
</div>  
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
    ({ name, modules }) => `
# ${name}
[点击前往](${config.base}list/${name})
共收录 ${modules.length} 个模组
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
