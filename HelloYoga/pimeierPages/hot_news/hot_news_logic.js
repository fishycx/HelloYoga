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
    // 注意：在 iOS 真机上，localhost 指向设备本身，需要使用开发机器的 IP 地址
    // 在模拟器上可以使用 localhost，在真机上需要替换为实际 IP
    // 例如：http://192.168.1.100:5001/api/news/latest
    var apiUrl = "http://10.23.204.224:5001/api/news/latest";
    
    // 如果分类不是"all"，可以添加分类参数（如果API支持）
    // if (categoryId !== "all") {
    //     apiUrl += "&category=" + categoryId;
    // }
    
    log("开始请求API: " + apiUrl);
    
    Pimeier.Network.get({
        url: apiUrl,
        timeout: 15
    })
    .then(function(response) {
        log("API响应: " + JSON.stringify(response));
        
        // NetworkModule 返回格式: { statusCode: 200, data: {...}, headers: {...} }
        // API 实际返回格式: { data: [...], success: true, total: 100 }
        // 所以访问路径是: response.data.data
        var apiData = response.data;
        
        log("API数据检查:");
        log("response.data 类型: " + typeof apiData);
        log("response.data.data 是否存在: " + (apiData && apiData.data !== undefined));
        log("response.data.data 是否为数组: " + (apiData && Array.isArray(apiData.data)));
        
        if (apiData && apiData.data && Array.isArray(apiData.data)) {
            // API返回格式: { data: [...], success: true, total: 100 }
            log("开始格式化数据，数组长度: " + apiData.data.length);
            var newsList = formatNewsData(apiData.data);
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
        log("错误详情: " + JSON.stringify(error));
        
        if (!viewModel.newsList) {
            viewModel.newsList = [];
        }
        
        // 检查是否是连接错误
        var errorMsg = error;
        if (error && error.indexOf("Could not connect") !== -1) {
            errorMsg = "无法连接到服务器\n请检查：\n1. 服务器是否运行在 localhost:5001\n2. 真机需要使用开发机器 IP 地址\n3. 网络连接是否正常";
        } else if (error && error.indexOf("timeout") !== -1) {
            errorMsg = "请求超时，请检查网络连接";
        }
        
        viewModel.newsList = [{
            templateType: "empty"
        }];
        viewModel.isRefreshing = false;
        render();
        Pimeier.Toast.show(errorMsg);
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
    
    if (news) {
        // 跳转到新闻详情页，传递新闻数据
        Pimeier.Navigation.pushPage({
            pageId: "news_detail",
            params: {
                newsId: news.id,
                news: news  // 传递完整的新闻对象
            }
        })
        .then(function() {
            log("跳转成功");
        })
        .catch(function(error) {
            log("跳转失败: " + error);
            Pimeier.Toast.show("无法打开新闻详情: " + error);
        });
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
        
        // 确保 item 是对象，并且所有字段都是基本类型
        if (!item || typeof item !== 'object' || Array.isArray(item)) {
            log("跳过无效数据项: " + i);
            continue;
        }
        
        // 判断是否有图片（可以根据平台或标题判断，或者API后续可能返回图片URL）
        var hasImage = false; // 当前API没有图片字段，后续如果有可以改为 item.image || item.imageUrl
        
        // 确保所有字段都有默认值，避免 undefined 导致的错误
        // 使用安全的类型转换，确保都是基本类型
        var rank = (item.rank !== undefined && item.rank !== null) ? Number(item.rank) : (i + 1);
        if (isNaN(rank) || rank <= 0) {
            rank = i + 1;
        }
        
        var platform = (item.platform && typeof item.platform === 'string') ? item.platform : "unknown";
        var title = (item.title && typeof item.title === 'string') ? item.title : "无标题";
        var source = (item.platform_name && typeof item.platform_name === 'string') ? item.platform_name : 
                     (item.platform && typeof item.platform === 'string') ? item.platform : "未知来源";
        var timestamp = (item.timestamp && typeof item.timestamp === 'string') ? item.timestamp : "";
        
        // 构建新闻对象，确保所有字段都是基本类型
        var news = {
            id: (item.id && typeof item.id === 'string') ? item.id : (String(rank) + "_" + platform + "_" + i),
            templateType: hasImage ? "news" : "news_text",
            title: String(title), // 确保是字符串
            source: String(source), // 确保是字符串
            time: String(formatTimeFromString(timestamp)), // 确保是字符串
            hot: Boolean(rank <= 3), // 确保是布尔值
            url: (item.url && typeof item.url === 'string') ? item.url : 
                 (item.link && typeof item.link === 'string') ? item.link : "",
            rank: Number(rank), // 确保是数字
            platform: String(platform) // 确保是字符串
        };
        
        // 如果有图片URL，添加图片
        if ((item.image && typeof item.image === 'string') || (item.imageUrl && typeof item.imageUrl === 'string')) {
            news.image = String(item.image || item.imageUrl);
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

