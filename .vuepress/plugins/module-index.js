const { ROLE_NAME } = require("../const");
const { base } = require("../config");
const readFileTree = require("read-file-tree");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const basePath = "module";
const outputPath = "module";

module.exports = (options, ctx) => ({
  additionalPages() {
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
        return prev.displayName > next.displayName ? 1 : -1;
      });
    return [
      {
        path: `/${outputPath}/`,
        content: `# 根据分类查看
共${categories.length}个分类

          ${categories
            .map(({ name, modules, displayName }) => {
              return `  
## ${displayName}  
[点击前往](./${name})  
共收录 ${modules.length} 个模组`;
            })
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
          const picPath = path.resolve(
            "module",
            name,
            _module.name,
            _module.pic
          );
          const picture = fs.readFileSync(picPath);
          const hash = crypto
            .createHash("md5")
            .update(picture)
            .digest("hex");

          const pic = `/assets/img/${_module.pic}`.replace(
            ".",
            `.${hash.substr(0, 8)}.`
          );
          return `<div class="col-sm-6 col-md-4 col-lg-3 col-xl-2" style="margin-bottom: 15px;text-align: center;">
  <h3 id="${_module.name}">
    <a href="./${_module.name}">
      <img :src="$withBase('${pic}')" />
      <div>${_module.name}</div>
      <div style="font-size:14px;">点击前往</div>
    </a>
  </h3>
</div>`;
        })
        .join("\n")}
</div>
      
<style>
  .${name}-page:before {
    ${
      fs.existsSync(backgroundPngPath)
        ? `background-image: url(data:image/png;base64,${fs.readFileSync(
            backgroundPngPath,
            "base64"
          )});`
        : ""
    }
    content: ' ';
    position: fixed;
    z-index: 0;
    top: 60px;
    right: 0;
    bottom: 0;
    left: 0;
    background-repeat: no-repeat;
    background-position: bottom right;
    background-size: contain;
    opacity: 0.5;
  }
  .${name}-page .content__default {
    max-width: 1200px;
  }
</style>`
        };
      })
    ];
  }
});
