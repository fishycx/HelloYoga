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

✅ **已集成真实API**

### API 信息

- **接口地址**: `http://localhost:5001/api/news/latest?limit=100`
- **请求方法**: GET
- **参数说明**:
  - `limit`: 返回新闻数量（默认100）

### API响应格式

```json
{
  "data": [
    {
      "platform": "toutiao",
      "platform_name": "今日头条",
      "rank": 1,
      "timestamp": "2025-12-04 16:45:10",
      "title": "新闻标题"
    }
  ],
  "success": true,
  "timestamp": "2025-12-04 16:51:19",
  "total": 100
}
```

### 数据字段说明

- `platform`: 平台标识（如 "toutiao", "baidu"）
- `platform_name`: 平台名称（显示为来源）
- `rank`: 排名（用于判断热点，前3名标记为🔥）
- `timestamp`: 时间戳字符串（格式: "YYYY-MM-DD HH:mm:ss"）
- `title`: 新闻标题

### 数据映射

API数据会自动映射到视图模型：
- `platform_name` → `source`（来源）
- `timestamp` → `time`（格式化后的相对时间）
- `rank <= 3` → `hot`（热点标记）
- `title` → `title`（标题）

### 配置说明

如需修改API地址，编辑 `hot_news_logic.js` 中的 `apiUrl` 变量：

```javascript
var apiUrl = "http://localhost:5001/api/news/latest?limit=100";
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

