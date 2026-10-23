# 앱의 유일한 화면. 전체 화면 WebView에 assets/index.html(소름테스트 웹앱)을 띄워요.
# 자바 대신 smali(안드로이드 어셈블리)로 쓴 이유: 이 빌드 환경에서는 공식 안드로이드 SDK를 받을 수 없어서
# Maven Central에 있는 오픈소스 smali 어셈블러로 바로 classes.dex를 만들기 때문이에요.
.class public Lcom/sorum/test/MainActivity;
.super Landroid/app/Activity;

.field private web:Landroid/webkit/WebView;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    .registers 6

    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    # 화면 꺼짐 방지(FLAG_KEEP_SCREEN_ON) + 상태바/내비바를 앱 배경색(#0f1f1c)으로
    invoke-virtual {p0}, Landroid/app/Activity;->getWindow()Landroid/view/Window;
    move-result-object v0
    const/16 v1, 0x80
    invoke-virtual {v0, v1}, Landroid/view/Window;->addFlags(I)V
    const v1, -0xf0e0e4
    invoke-virtual {v0, v1}, Landroid/view/Window;->setStatusBarColor(I)V
    invoke-virtual {v0, v1}, Landroid/view/Window;->setNavigationBarColor(I)V

    new-instance v0, Landroid/webkit/WebView;
    invoke-direct {v0, p0}, Landroid/webkit/WebView;-><init>(Landroid/content/Context;)V
    invoke-virtual {v0, v1}, Landroid/webkit/WebView;->setBackgroundColor(I)V
    iput-object v0, p0, Lcom/sorum/test/MainActivity;->web:Landroid/webkit/WebView;

    # 자바스크립트와 localStorage(설정 기억용) 켜기
    invoke-virtual {v0}, Landroid/webkit/WebView;->getSettings()Landroid/webkit/WebSettings;
    move-result-object v2
    const/4 v3, 0x1
    invoke-virtual {v2, v3}, Landroid/webkit/WebSettings;->setJavaScriptEnabled(Z)V
    invoke-virtual {v2, v3}, Landroid/webkit/WebSettings;->setDomStorageEnabled(Z)V

    const-string v3, "file:///android_asset/index.html"
    invoke-virtual {v0, v3}, Landroid/webkit/WebView;->loadUrl(Ljava/lang/String;)V
    invoke-virtual {p0, v0}, Landroid/app/Activity;->setContentView(Landroid/view/View;)V
    return-void
.end method

# 뒤로가기: 게임 중이면 첫 화면으로, 첫 화면이면 앱 종료
.method public onBackPressed()V
    .registers 3
    iget-object v0, p0, Lcom/sorum/test/MainActivity;->web:Landroid/webkit/WebView;
    if-eqz v0, :exit
    invoke-virtual {v0}, Landroid/webkit/WebView;->canGoBack()Z
    move-result v1
    if-eqz v1, :exit
    invoke-virtual {v0}, Landroid/webkit/WebView;->goBack()V
    return-void
    :exit
    invoke-super {p0}, Landroid/app/Activity;->onBackPressed()V
    return-void
.end method
