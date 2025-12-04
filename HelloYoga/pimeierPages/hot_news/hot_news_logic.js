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
    
    // 调用真实API
    var apiUrl = "http://localhost:5001/api/news/latest?limit=100";
    
    // 如果分类不是"all"，可以添加分类参数（如果API支持）
    // if (categoryId !== "all") {
    //     apiUrl += "&category=" + categoryId;
    // }
    
    Pimeier.Network.get({
        url: apiUrl,
        timeout: 15
    })
    .then(function(response) {
        log("API响应: " + JSON.stringify(response));
        
        if (response.data && response.data.data && Array.isArray(response.data.data)) {
            // API返回格式: { data: { data: [...], success: true, total: 100 } }
            var newsList = formatNewsData(response.data.data);
            if (!viewModel.newsList) {
                viewModel.newsList = [];
            }
            viewModel.newsList = newsList;
            viewModel.isRefreshing = false;
            viewModel.updateTime = getCurrentTime();
            render();
            
            log("加载成功，共 " + newsList.length + " 条新闻");
        } else {
            log("API返回数据格式异常");
            if (!viewModel.newsList) {
                viewModel.newsList = [];
            }
            viewModel.newsList = [{ templateType: "empty" }];
            viewModel.isRefreshing = false;
            render();
            Pimeier.Toast.show("数据格式错误");
        }
    })
    .catch(function(error) {
        log("加载新闻失败: " + error);
        if (!viewModel.newsList) {
            viewModel.newsList = [];
        }
        viewModel.newsList = [{ templateType: "empty" }];
        viewModel.isRefreshing = false;
        render();
        Pimeier.Toast.show("加载失败: " + error);
    });
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
// API数据格式: { platform, platform_name, rank, timestamp, title }
function formatNewsData(apiData) {
    var newsList = [];
    
    if (!apiData || !Array.isArray(apiData)) {
        return [{ templateType: "empty" }];
    }
    
    for (var i = 0; i < apiData.length; i++) {
        var item = apiData[i];
        
        // 判断是否有图片（可以根据平台或标题判断，或者API后续可能返回图片URL）
        var hasImage = false; // 当前API没有图片字段，后续如果有可以改为 item.image || item.imageUrl
        
        var news = {
            id: item.id || item.rank + "_" + item.platform + "_" + i, // 使用 rank + platform + index 作为唯一ID
            templateType: hasImage ? "news" : "news_text",
            title: item.title || "无标题",
            source: item.platform_name || item.platform || "未知来源",
            time: formatTimeFromString(item.timestamp), // 格式化时间戳字符串
            hot: item.rank <= 3, // 排名前3的标记为热点
            url: item.url || item.link || "", // 如果API后续返回URL
            rank: item.rank || (i + 1), // 保存排名信息
            platform: item.platform || "" // 保存平台信息
        };
        
        // 如果有图片URL，添加图片
        if (item.image || item.imageUrl) {
            news.image = item.image || item.imageUrl;
            news.templateType = "news";
        }
        
        newsList.push(news);
    }
    
    return newsList.length > 0 ? newsList : [{ templateType: "empty" }];
}

// 格式化时间（从时间戳字符串）
// API返回格式: "2025-12-04 16:45:10"
function formatTimeFromString(timeString) {
    if (!timeString) return "未知时间";
    
    try {
        // 解析时间字符串 "2025-12-04 16:45:10"
        var timeParts = timeString.split(" ");
        if (timeParts.length !== 2) {
            return timeString; // 如果格式不对，直接返回原字符串
        }
        
        var dateParts = timeParts[0].split("-");
        var timeParts2 = timeParts[1].split(":");
        
        if (dateParts.length !== 3 || timeParts2.length !== 3) {
            return timeString;
        }
        
        // 创建Date对象
        var time = new Date(
            parseInt(dateParts[0]), // 年
            parseInt(dateParts[1]) - 1, // 月（0-11）
            parseInt(dateParts[2]), // 日
            parseInt(timeParts2[0]), // 时
            parseInt(timeParts2[1]), // 分
            parseInt(timeParts2[2]) // 秒
        );
        
        var now = new Date();
        var diff = now.getTime() - time.getTime();
        
        if (diff < 0) {
            return "刚刚"; // 如果时间在未来，显示"刚刚"
        } else if (diff < 60000) {
            return "刚刚";
        } else if (diff < 3600000) {
            return Math.floor(diff / 60000) + "分钟前";
        } else if (diff < 86400000) {
            return Math.floor(diff / 3600000) + "小时前";
        } else if (diff < 604800000) {
            return Math.floor(diff / 86400000) + "天前";
        } else {
            // 超过一周，显示具体日期
            return timeParts[0]; // 返回日期部分
        }
    } catch (e) {
        log("时间格式化错误: " + e);
        return timeString;
    }
}

// 格式化时间（从时间戳数字，保留作为备用）
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

