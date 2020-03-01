const { ROLE_NAME } = require("../const");
const { base } = require("../config");
const readFileTree = require("read-file-tree");
const fs = require("fs");
const path = require("path");
const basePath = "module";
const outputPath = "module";

module.exports = {
  async additionalPages() {
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
          displayName: ROLE_NAME[categoryName] || categoryName,
          modules
        };
      })
      .sort((prev, next) => {
        return prev.displayName - next.displayName;
      });
    return [
      {
        path: `/${outputPath}/`,
        content: `# 根据分类查看
          ${categories
            .map(
              ({ name, modules, displayName }) => `
          ## ${displayName}
          [点击前往](${base}module/${name})
          共收录 ${modules.length} 个模组
          `
            )
            .join("\n")}
          `
      },
      ...categories.map(({ name, modules, displayName }) => {
        const backgroundPngPath = path.resolve(
          outputPath,
          name,
          "background.png"
        );
        return {
          path: `/${outputPath}/${name}/`,
          content: `---
sidebar: false
pageClass: ${name}-page
---    
# ${displayName}
> 模组列表 已收录${modules.length}个模组

<div class="row">
      ${modules
        .reverse()
        .map(_module => {
          const pic = `./${[_module.name, _module.pic].join("/")}`;
          return `<div class="col-sm-24 col-md-6 col-lg-6 col-xl-4" style="margin-bottom: 15px;text-align: center;">
            <h3 id="${_module.name}">
              <a href="${base}module/${name}/${_module.name}">
                <img src="${pic}" />
                <div>${_module.name}</div>
                <div>点击前往</div>
              </a>
            </h3>
          </div>`;
        })
        .join("\n")}
</div>
      
<style>
  .${name}-page {
    ${
      fs.existsSync(backgroundPngPath)
        ? "background-image: url(./background.png);"
        : ""
    }
    background-color: #ffffff;
    background-repeat: no-repeat;
    background-attachment: fixed;
    background-position: bottom right;
    background-size: 30vmin;
  }  
</style>`
        };
      })
    ];
  }
};
