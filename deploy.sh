#!/bin/bash

# Hexo博客自动部署脚本
# 使用方法：./deploy.sh "提交信息"

echo "🚀 开始部署博客..."

# 清理并重新生成网站
echo "📦 清理并生成网站文件..."
hexo clean
hexo generate

# 将生成的文件复制到根目录（GitHub Pages需要）
echo "📋 复制网站文件到根目录..."
cp -r public/* .

# 确保.nojekyll文件存在（禁用Jekyll）
echo "🚫 确保.nojekyll文件存在..."
touch .nojekyll

# 检查是否有提交信息参数
if [ $# -eq 0 ]; then
    COMMIT_MSG="更新博客内容 $(date '+%Y-%m-%d %H:%M:%S')"
else
    COMMIT_MSG="$1"
fi

echo "📝 提交信息：$COMMIT_MSG"

# 添加所有更改到git
echo "📋 添加文件到Git..."
git add .

# 提交更改
echo "💾 提交更改..."
git commit -m "$COMMIT_MSG"

# 推送到GitHub
echo "🌐 推送到GitHub..."
git push origin main

echo "✅ 博客部署完成！"
echo "🔗 你的博客地址：https://q164129345.github.io"
echo ""
echo "💡 提示：GitHub Pages可能需要几分钟时间更新，请耐心等待。" 