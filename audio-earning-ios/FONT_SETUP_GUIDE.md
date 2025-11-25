# 字體配置指南 - iOS 項目

本指南將幫助你在 Xcode 中配置新添加的自定義字體（Space Mono、Cormorant Garamond、Tangerine）。

---

## 📁 字體文件位置

所有字體文件已複製到：
```
audio-earning-ios/audio-earning/Resources/Fonts/
```

包含以下文件：
- `SpaceMono-Regular.ttf`
- `SpaceMono-Bold.ttf`
- `CormorantGaramond-Regular.ttf`
- `CormorantGaramond-Medium.ttf`
- `CormorantGaramond-Bold.ttf`
- `Tangerine-Regular.ttf`
- `Tangerine-Bold.ttf`

---

## 🔧 Xcode 配置步驟

### 步驟 1: 添加字體文件到 Xcode 項目

1. **打開 Xcode 項目**
   ```
   open audio-earning-ios/audio-earning.xcodeproj
   ```

2. **在左側 Project Navigator 中找到 `audio-earning` 文件夾**

3. **將 `Resources` 文件夾拖入 Xcode**
   - 在 Finder 中打開 `audio-earning-ios/audio-earning/Resources/`
   - 將整個 `Resources` 文件夾拖到 Xcode 的 `audio-earning` 項目中

4. **在彈出的對話框中確認選項**：
   - ✅ **Copy items if needed** （重要！）
   - ✅ **Create groups**
   - ✅ **Add to targets: audio-earning**
   - 點擊 **Finish**

5. **驗證文件已添加**
   - 在 Project Navigator 中應該能看到 `Resources/Fonts/` 文件夾
   - 點擊任一 `.ttf` 文件
   - 在右側 File Inspector 確認 **Target Membership** 中 `audio-earning` 已勾選

---

### 步驟 2: 配置 Info.plist

1. **在 Project Navigator 中找到並打開 `Info.plist`**
   - 通常位於 `audio-earning/Info.plist`

2. **添加字體聲明**：

   **方法 A: 使用 Xcode UI**
   - 右鍵點擊空白處 → **Add Row**
   - Key 輸入: `Fonts provided by application`
   - 類型會自動變為 `Array`
   - 展開這個數組，添加以下 7 個 String 項目：

   ```
   Item 0: SpaceMono-Regular.ttf
   Item 1: SpaceMono-Bold.ttf
   Item 2: CormorantGaramond-Regular.ttf
   Item 3: CormorantGaramond-Medium.ttf
   Item 4: CormorantGaramond-Bold.ttf
   Item 5: Tangerine-Regular.ttf
   Item 6: Tangerine-Bold.ttf
   ```

   **方法 B: 直接編輯源代碼**
   - 右鍵 `Info.plist` → **Open As** → **Source Code**
   - 在 `<dict>` 標籤內添加：

   ```xml
   <key>UIAppFonts</key>
   <array>
       <string>SpaceMono-Regular.ttf</string>
       <string>SpaceMono-Bold.ttf</string>
       <string>CormorantGaramond-Regular.ttf</string>
       <string>CormorantGaramond-Medium.ttf</string>
       <string>CormorantGaramond-Bold.ttf</string>
       <string>Tangerine-Regular.ttf</string>
       <string>Tangerine-Bold.ttf</string>
   </array>
   ```

---

### 步驟 3: 驗證字體已正確加載

1. **在 AppDelegate 或主入口添加測試代碼**（可選，用於調試）：

   在 `audio-earningApp.swift` 的 `init()` 中添加：
   ```swift
   init() {
       // Print all available fonts for debugging
       for family in UIFont.familyNames.sorted() {
           let names = UIFont.fontNames(forFamilyName: family)
           print("Family: \(family) - Fonts: \(names)")
       }
   }
   ```

2. **運行應用**
   - Command + R 或點擊 ▶️ 按鈕
   - 在 Console 中搜索以下字體名稱：
     - `SpaceMono`
     - `CormorantGaramond`
     - `Tangerine`

3. **測試字體選擇器**
   - 打開任何新聞文章
   - 點擊右上角設置按鈕（textformat.size）
   - 在「標題字體」或「內文字體」中應該能看到新字體

---

## ✅ 成功標誌

配置成功後，你應該能：
- ✅ 在設置頁面中看到 6 個字體選項（包含新增的 3 個）
- ✅ 切換字體時，預覽區域的文字立即改變
- ✅ 字體應用到新聞文章的標題和內文

---

## 🐛 常見問題排查

### 問題 1: 字體沒有顯示
**原因**: Info.plist 中的字體文件名錯誤
**解決**: 確認文件名與實際文件完全一致（包含大小寫和 `.ttf` 後綴）

### 問題 2: 字體使用系統 fallback
**原因**: 字體文件未添加到 target
**解決**:
1. 點擊字體文件
2. 在右側 File Inspector 確認 Target Membership
3. 勾選 `audio-earning`

### 問題 3: 編譯錯誤
**原因**: 字體文件路徑問題
**解決**:
1. 刪除 `Resources` 文件夾從 Xcode
2. 重新拖入並確認 "Copy items if needed" 已勾選

### 問題 4: 查看實際字體名稱
**方法**: 在 Terminal 中運行
```bash
fc-scan --format "%{family}\n" SpaceMono-Regular.ttf
```

---

## 📚 字體特性

### Space Mono
- **風格**: 等寬字體（Monospace）
- **適合**: 程式碼片段、技術文章
- **權重**: Regular, Bold

### Cormorant Garamond
- **風格**: 優雅襯線字體（Elegant Serif）
- **適合**: 長文閱讀、文學作品
- **權重**: Regular, Medium, Bold

### Tangerine
- **風格**: 手寫草書字體（Handwriting Script）
- **適合**: 標題、引用文字
- **權重**: Regular, Bold
- **注意**: 由於是草書字體，建議只用於標題，不適合長文閱讀

---

## 🎨 使用建議

**推薦組合**：
- **經典閱讀**: 標題 `Cormorant Garamond Bold` + 內文 `Cormorant Garamond Regular`
- **現代科技**: 標題 `Space Mono Bold` + 內文 `SF Pro`
- **優雅風格**: 標題 `Tangerine Bold` + 內文 `New York`

---

完成以上步驟後，字體配置就完成了！🎉
