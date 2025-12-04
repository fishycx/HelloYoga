# 热榜新闻应用

## 项目简介

这是一个聚合全网热榜新闻的应用，旨在减少用户的搜索成本，快速获取热点资讯。

## 功能特性

- ✅ 多分类浏览（全部、科技、娱乐、体育、财经、社会）
- ✅ 新闻列表展示（支持图片和纯文字两种样式）
- ✅ 热点标记（🔥）
- ✅ 下拉刷新
- ✅ 分类切换
- ✅ 新闻详情跳转（待实现）

## 页面结构

```
hot_news/
├── hot_news_layout.xml    # 布局文件
├── hot_news_data.json     # 初始数据
├── hot_news_logic.js      # 业务逻辑
└── README.md              # 说明文档
```

## 使用方式

在 `TestViewController` 中选择 `hot_news` 即可查看热榜新闻页面。

## API 集成

当前使用模拟数据，实际项目中需要替换为真实API。

### 推荐API服务

1. **聚合数据** (https://www.juhe.cn/)
   - 提供新闻API
   - 需要注册获取API Key

2. **天行数据** (https://www.tianapi.com/)
   - 提供热点新闻API
   - 免费额度有限

3. **NewsAPI** (https://newsapi.org/)
   - 国际新闻API
   - 需要注册

### 集成步骤

1. 在 `hot_news_logic.js` 中找到 `loadNews()` 函数
2. 取消注释真实API调用代码
3. 替换API地址和参数
4. 根据API响应格式调整 `formatNewsData()` 函数

### API响应格式示例

```json
{
  "code": 200,
  "data": {
    "list": [
      {
        "id": "1",
        "title": "新闻标题",
        "source": "来源",
        "time": 1234567890,
        "image": "https://example.com/image.jpg",
        "url": "https://example.com/news/1",
        "hot": true
      }
    ]
  }
}
```

## 待实现功能

- [ ] 新闻详情页面
- [ ] 搜索功能
- [ ] 收藏功能
- [ ] 分享功能
- [ ] 夜间模式
- [ ] 个性化推荐

## 技术栈

- **框架**: Pimeier
- **布局**: XML + Flexbox
- **数据**: JSON
- **逻辑**: JavaScript
- **网络**: Pimeier.Network

