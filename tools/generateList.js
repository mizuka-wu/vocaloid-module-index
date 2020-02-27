const readFileTree = require("read-file-tree");
const fs = require("fs");
const path = require("path");
const config = require("../.vuepress/config");

const basePath = "module";
const outputPath = "module";

const tree = readFileTree.sync(basePath);

const categories = Object.keys(tree)
  .filter(categoryName => {
    return !Buffer.isBuffer(tree[categoryName]);
  })
  .map(categoryName => {
    const category = tree[categoryName];
    const modules = Object.keys(category)
      .filter(moduleName => {
        return !Buffer.isBuffer(category[moduleName]);
      })
      .map(moduleName => ({
        name: moduleName,
        pic: "index.jpg"
      }));
    return {
      name: categoryName,
      modules
    };
  });

/** 增加list文件 */
categories.forEach(({ name, modules }) => {
  fs.writeFileSync(
    path.resolve(outputPath, name, "README.md"),
    `
# ${name}
模组：
<div class="row">
${modules
  .map(_module => {
    const pic = `./${[name, _module.name, _module.pic].join("/")}`;
    return `<div class="col-sm-24 col-md-6 col-lg-6 col-xl-4" style="margin-bottom: 15px;text-align: center;">
      <a href="${config.base}module/${name}/${_module.name}">
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
## ${name}
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
      link: `/module/${name}/`
    })),
    null,
    2
  ),
  { flag: "w" }
);
