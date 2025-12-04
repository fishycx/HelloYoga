// 热榜新闻页面逻辑

// 初始化
function init() {
    log("热榜新闻页面初始化");
    loadNews("all");
}

// 加载新闻数据
function loadNews(categoryId) {
    log("加载新闻，分类: " + categoryId);
    
    // 显示加载状态
    viewModel.isRefreshing = true;
    if (!viewModel.newsList) {
        viewModel.newsList = [];
    }
    viewModel.newsList = [
        {
            templateType: "loading"
        }
    ];
    render();
    
    // 更新分类状态（通过重新渲染时更新分类文本样式）
    viewModel.currentCategory = categoryId;
    
    // 模拟API调用 - 实际项目中替换为真实API
    // 这里使用模拟数据，实际应该调用 Pimeier.Network.get()
    setTimeout(function() {
        // 模拟数据
        var mockNews = generateMockNews(categoryId);
        if (!viewModel.newsList) {
            viewModel.newsList = [];
        }
        viewModel.newsList = mockNews;
        viewModel.isRefreshing = false;
        viewModel.updateTime = getCurrentTime();
        render();
        
        Pimeier.Toast.show("加载完成");
    }, 1000);
    
    // 实际API调用示例（需要替换为真实API地址）
    /*
    Pimeier.Network.get({
        url: "https://api.example.com/news?category=" + categoryId,
        timeout: 10
    })
    .then(function(response) {
        if (response.data && response.data.list) {
            viewModel.newsList = formatNewsData(response.data.list);
        } else {
            viewModel.newsList = [{ templateType: "empty" }];
        }
        viewModel.isRefreshing = false;
        viewModel.updateTime = getCurrentTime();
        render();
    })
    .catch(function(error) {
        log("加载新闻失败: " + error);
        viewModel.newsList = [{ templateType: "empty" }];
        viewModel.isRefreshing = false;
        render();
        Pimeier.Toast.show("加载失败: " + error);
    });
    */
}

// 切换分类
function switchCategory(categoryId) {
    log("切换分类: " + categoryId);
    if (viewModel.currentCategory === categoryId) {
        return; // 已经是当前分类，不重复加载
    }
    loadNews(categoryId);
}

// 打开新闻详情
function openNewsDetail(newsId) {
    log("打开新闻详情: " + newsId);
    
    // 查找新闻数据
    var news = null;
    if (viewModel.newsList) {
        for (var i = 0; i < viewModel.newsList.length; i++) {
            if (viewModel.newsList[i].id === newsId) {
                news = viewModel.newsList[i];
                break;
            }
        }
    }
    
    if (news && news.url) {
        // 实际项目中可以打开详情页或浏览器
        Pimeier.Toast.show("打开新闻: " + news.title);
        // 这里可以调用 Native Bridge 打开浏览器或详情页
        // Pimeier.Browser.open(news.url);
    } else {
        Pimeier.Toast.show("新闻详情暂不可用");
    }
}

// 下拉刷新
function onRefresh() {
    log("下拉刷新");
    loadNews(viewModel.currentCategory || "all");
}

// 生成模拟数据
function generateMockNews(categoryId) {
    var categories = {
        "all": ["科技", "娱乐", "体育", "财经", "社会"],
        "tech": ["科技"],
        "entertainment": ["娱乐"],
        "sports": ["体育"],
        "finance": ["财经"],
        "society": ["社会"]
    };
    
    var sources = ["新浪新闻", "腾讯新闻", "网易新闻", "今日头条", "澎湃新闻"];
    var times = ["刚刚", "5分钟前", "10分钟前", "1小时前", "2小时前", "3小时前"];
    
    var newsList = [];
    var categoryNames = categories[categoryId] || categories["all"];
    
    for (var i = 0; i < 10; i++) {
        var hasImage = Math.random() > 0.3; // 70% 概率有图片
        var isHot = Math.random() > 0.7; // 30% 概率是热点
        
        var news = {
            id: String(i + 1),
            templateType: hasImage ? "news" : "news_text",
            title: categoryNames[Math.floor(Math.random() * categoryNames.length)] + "热点新闻 " + (i + 1) + "：这是一个示例新闻标题，用于演示热榜新闻应用的界面效果",
            source: sources[Math.floor(Math.random() * sources.length)],
            time: times[Math.floor(Math.random() * times.length)],
            hot: isHot,
            url: "https://example.com/news/" + (i + 1)
        };
        
        if (hasImage) {
            news.image = "https://picsum.photos/200/150?random=" + (i + 1);
        }
        
        newsList.push(news);
    }
    
    return newsList;
}

// 格式化新闻数据（从API响应转换为视图模型）
function formatNewsData(apiData) {
    var newsList = [];
    
    if (!apiData || !Array.isArray(apiData)) {
        return [{ templateType: "empty" }];
    }
    
    for (var i = 0; i < apiData.length; i++) {
        var item = apiData[i];
        var news = {
            id: item.id || String(i + 1),
            templateType: item.image ? "news" : "news_text",
            title: item.title || "无标题",
            source: item.source || "未知来源",
            time: formatTime(item.time || item.publishTime),
            hot: item.hot || false,
            url: item.url || item.link || ""
        };
        
        if (item.image) {
            news.image = item.image;
        }
        
        newsList.push(news);
    }
    
    return newsList.length > 0 ? newsList : [{ templateType: "empty" }];
}

// 格式化时间
function formatTime(timestamp) {
    if (!timestamp) return "未知时间";
    
    var now = new Date().getTime();
    var time = new Date(timestamp).getTime();
    var diff = now - time;
    
    if (diff < 60000) {
        return "刚刚";
    } else if (diff < 3600000) {
        return Math.floor(diff / 60000) + "分钟前";
    } else if (diff < 86400000) {
        return Math.floor(diff / 3600000) + "小时前";
    } else {
        return Math.floor(diff / 86400000) + "天前";
    }
}

// 获取当前时间字符串
function getCurrentTime() {
    var now = new Date();
    var hours = now.getHours();
    var minutes = now.getMinutes();
    return (hours < 10 ? "0" + hours : hours) + ":" + (minutes < 10 ? "0" + minutes : minutes) + " 更新";
}

// 页面加载时自动初始化
(function() {
    function tryInit() {
        if (typeof viewModel !== 'undefined') {
            init();
        } else {
            setTimeout(tryInit, 50);
        }
    }
    tryInit();
})();

