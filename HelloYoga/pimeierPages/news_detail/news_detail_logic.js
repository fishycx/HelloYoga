// 新闻详情页逻辑

// 初始化
function init() {
    log("新闻详情页初始化");
    log("viewModel keys: " + Object.keys(viewModel).join(", "));
    
    // 参数已经通过 PimeierViewController 合并到 viewModel 中
    // 检查 viewModel 中是否有传递的参数
    
    // 首先确保 isLoading 被设置为 false，避免一直显示"加载中..."
    var hasNews = false;
    var hasUrl = false;
    
    // 检查是否有 news 对象
    if (viewModel.news && typeof viewModel.news === 'object') {
        try {
            log("检测到 news 参数: " + JSON.stringify(viewModel.news));
            var news = viewModel.news;
            viewModel.title = (news.title && typeof news.title === 'string') ? news.title : "新闻详情";
            viewModel.source = (news.source && typeof news.source === 'string') ? news.source : "";
            viewModel.time = (news.time && typeof news.time === 'string') ? news.time : "";
            viewModel.hot = (news.hot === true || news.hot === false) ? news.hot : false;
            
            // 优先使用新闻的 URL，如果没有则根据平台构造搜索链接
            var newsUrl = "";
            if (news.url && typeof news.url === 'string' && news.url !== "") {
                newsUrl = news.url;
            } else if (news.link && typeof news.link === 'string' && news.link !== "") {
                newsUrl = news.link;
            } else {
                // 根据平台和标题构造搜索 URL
                var platform = (news.platform && typeof news.platform === 'string') ? news.platform : "";
                var title = viewModel.title;
                
                if (platform && title) {
                    // 根据不同平台构造不同的搜索 URL
                    if (platform.indexOf("baidu") !== -1) {
                        newsUrl = "https://www.baidu.com/s?wd=" + encodeURIComponent(title);
                    } else if (platform.indexOf("toutiao") !== -1) {
                        newsUrl = "https://www.toutiao.com/search/?keyword=" + encodeURIComponent(title);
                    } else if (platform.indexOf("weibo") !== -1) {
                        newsUrl = "https://s.weibo.com/weibo?q=" + encodeURIComponent(title);
                    } else if (platform.indexOf("bilibili") !== -1) {
                        newsUrl = "https://search.bilibili.com/all?keyword=" + encodeURIComponent(title);
                    } else {
                        // 默认使用百度搜索
                        newsUrl = "https://www.baidu.com/s?wd=" + encodeURIComponent(title);
                    }
                    log("根据平台和标题构造 URL: " + newsUrl);
                } else {
                    // 如果连平台和标题都没有，使用默认搜索
                    newsUrl = "https://www.baidu.com/s?wd=" + encodeURIComponent(title || "新闻");
                }
            }
            
            viewModel.url = newsUrl;
            hasNews = true;
            hasUrl = true;
            log("设置后的 viewModel.url: " + viewModel.url);
        } catch (e) {
            log("解析 news 对象失败: " + e);
        }
    }
    
    // 如果没有 news，检查是否有 newsId
    if (!hasNews && viewModel.newsId) {
        log("检测到 newsId 参数: " + viewModel.newsId);
        loadNewsDetail(viewModel.newsId);
        return; // loadNewsDetail 会自己处理 isLoading 和 render
    }
    
    // 如果没有 news 和 newsId，检查是否有 url
    if (!hasUrl && viewModel.url && typeof viewModel.url === 'string' && viewModel.url !== "") {
        log("检测到 url 参数: " + viewModel.url);
        hasUrl = true;
    }
    
    // 如果都没有，使用默认值
    if (!hasUrl) {
        log("未检测到参数，使用默认 URL");
        viewModel.url = "https://www.baidu.com";
    }
    
    if (viewModel.title === "加载中..." || !viewModel.title) {
        viewModel.title = "新闻详情";
    }
    
    // 确保 isLoading 被设置为 false
    viewModel.isLoading = false;
    log("最终设置: url=" + viewModel.url + ", isLoading=" + viewModel.isLoading);
    render();
}

// 加载新闻详情（通过 ID）
function loadNewsDetail(newsId) {
    log("加载新闻详情: " + newsId);
    
    viewModel.isLoading = true;
    render();
    
    // 这里可以调用 API 获取新闻详情
    // 目前使用模拟数据
    // 实际项目中可以调用: Pimeier.Network.get({ url: "http://api.example.com/news/" + newsId })
    
    // 模拟加载
    setTimeout(function() {
        viewModel.title = "新闻标题 " + newsId;
        viewModel.source = "示例来源";
        viewModel.time = "刚刚";
        viewModel.hot = true;
        viewModel.url = "https://www.baidu.com"; // 示例 URL
        viewModel.isLoading = false;
        render();
    }, 500);
}

// 返回上一页
function goBack() {
    log("返回上一页");
    Pimeier.Navigation.popPage()
        .then(function() {
            log("返回成功");
        })
        .catch(function(error) {
            log("返回失败: " + error);
        });
}

// 页面加载时自动初始化
// 注意：viewModel 是在 logic.js 加载后才注入的，所以需要延迟初始化
(function() {
    function tryInit() {
        if (typeof viewModel !== 'undefined' && viewModel !== null) {
            // 确保 viewModel 已经包含数据
            var keys = Object.keys(viewModel);
            if (keys.length > 0) {
                log("viewModel 已准备好，开始初始化，keys: " + keys.join(", "));
                init();
            } else {
                // viewModel 存在但为空，再等一会儿
                setTimeout(tryInit, 100);
            }
        } else {
            setTimeout(tryInit, 50);
        }
    }
    // 延迟执行，确保 viewModel 已经被注入
    setTimeout(tryInit, 100);
})();

