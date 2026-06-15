# JustSync

一个iOS应用，可以通过本地Web服务器共享和管理iPhone相册中的照片和视频。

## 功能特性

- 📷 访问和浏览iPhone相册中的所有照片和视频
- 🌐 通过Web界面在同一局域网内访问照片
- 🖼️ 支持照片缩略图和全尺寸预览
- 🎥 支持视频播放
- 📍 显示照片的GPS位置信息和EXIF数据
- 🗑️ 支持批量选择和删除照片
- ⬇️ 支持批量下载照片到其他设备

## 项目结构

```
justsync/
├── justsync/
│   ├── justsyncApp.swift          # 应用入口
│   ├── ContentView.swift          # 主界面UI
│   ├── PhotoLibraryManager.swift  # 相册管理器
│   ├── WebServerManager.swift     # Web服务器管理
│   └── WebInterface.swift         # Web界面HTML
├── justsyncTests/                 # 单元测试
└── justsyncUITests/               # UI测试
```

## 权限配置

项目已配置以下权限：

- **NSPhotoLibraryUsageDescription**: 访问照片库以便通过Web界面共享和管理照片
- **NSPhotoLibraryAddUsageDescription**: 管理照片的权限
- **NSLocalNetworkUsageDescription**: 使用本地网络来提供Web服务

## 使用方法

1. 在Xcode中打开 `justsync.xcodeproj`
2. 选择目标设备（真机或模拟器）
3. 点击运行按钮构建并运行应用
4. 在应用中点击"启动服务器"按钮
5. 授予相册访问权限
6. 应用会显示本地网络地址（如：http://192.168.1.100:8080）
7. 在同一局域网的其他设备上通过浏览器访问该地址

## 技术栈

- Swift 5.0
- SwiftUI
- Photos Framework
- Network Framework
- iOS 16.4+

## 注意事项

- 需要在真机上运行才能访问真实的照片库
- 确保设备连接在同一局域网内
- Web服务器运行在8080端口

## 代码迁移说明

本项目已从 `old/` 文件夹的代码完全迁移到新的项目结构中，包括：

- ✅ PhotoLibraryManager.swift - 相册管理功能
- ✅ WebServerManager.swift - Web服务器功能  
- ✅ WebInterface.swift - Web前端界面
- ✅ ContentView.swift - iOS应用UI
- ✅ justsyncApp.swift - 应用入口
- ✅ Info.plist权限配置 - 通过INFOPLIST_KEY方式配置

所有业务代码已成功整合，项目可以在Xcode中正常构建和运行。
