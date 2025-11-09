#!/bin/bash
# Render 部署驗證腳本

set -e

SERVICE_URL="https://storytelling-backend-qiuj.onrender.com"

echo "🔍 開始驗證 Render 部署..."
echo ""

# 1. 健康檢查
echo "1️⃣ 健康檢查..."
HEALTH=$(curl -s "${SERVICE_URL}/health")
if echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo "   ✅ 健康檢查通過: $HEALTH"
else
    echo "   ❌ 健康檢查失敗: $HEALTH"
    exit 1
fi
echo ""

# 2. GCS 診斷
echo "2️⃣ GCS 連接診斷..."
GCS_DEBUG=$(curl -s "${SERVICE_URL}/debug/gcs")
if echo "$GCS_DEBUG" | grep -q '"bucket_exists":true'; then
    echo "   ✅ GCS 連接正常"
    echo "$GCS_DEBUG" | grep -o '"bucket":"[^"]*"' || true
else
    echo "   ⚠️  GCS 連接異常，請檢查詳細資訊："
    echo "$GCS_DEBUG" | head -20
fi
echo ""

# 3. API 測試
echo "3️⃣ API 端點測試..."
BOOKS=$(curl -s "${SERVICE_URL}/books")
if echo "$BOOKS" | grep -q '\['; then
    BOOK_COUNT=$(echo "$BOOKS" | grep -o '"id"' | wc -l | tr -d ' ')
    echo "   ✅ 書籍列表正常 (找到 $BOOK_COUNT 本書)"
else
    echo "   ❌ API 端點失敗: $BOOKS"
    exit 1
fi
echo ""

# 4. 測試章節端點
echo "4️⃣ 章節端點測試..."
FIRST_BOOK=$(echo "$BOOKS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -n "$FIRST_BOOK" ]; then
    CHAPTERS=$(curl -s "${SERVICE_URL}/books/${FIRST_BOOK}/chapters")
    if echo "$CHAPTERS" | grep -q '\['; then
        CHAPTER_COUNT=$(echo "$CHAPTERS" | grep -o '"id"' | wc -l | tr -d ' ')
        echo "   ✅ 章節列表正常 (書籍 '$FIRST_BOOK' 有 $CHAPTER_COUNT 章)"
    else
        echo "   ⚠️  章節列表為空或錯誤"
    fi
else
    echo "   ⚠️  沒有找到書籍，跳過章節測試"
fi
echo ""

# 5. 音頻端點測試
echo "5️⃣ 音頻端點測試..."
if [ -n "$FIRST_BOOK" ]; then
    FIRST_CHAPTER=$(echo "$CHAPTERS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$FIRST_CHAPTER" ]; then
        AUDIO_RESPONSE=$(curl -sI "${SERVICE_URL}/books/${FIRST_BOOK}/chapters/${FIRST_CHAPTER}/audio")
        if echo "$AUDIO_RESPONSE" | grep -q "HTTP.*307"; then
            LOCATION=$(echo "$AUDIO_RESPONSE" | grep -i "^location:" | cut -d' ' -f2 | tr -d '\r')
            echo "   ✅ 音頻轉址正常"
            echo "   → GCS URL: ${LOCATION:0:80}..."
        else
            echo "   ⚠️  音頻端點回應異常"
            echo "$AUDIO_RESPONSE" | head -3
        fi
    fi
fi
echo ""

echo "🎉 驗證完成！"
echo ""
echo "📊 服務資訊："
echo "   URL: $SERVICE_URL"
echo "   健康檢查: ${SERVICE_URL}/health"
echo "   API 文檔: ${SERVICE_URL}/docs"
echo "   GCS 診斷: ${SERVICE_URL}/debug/gcs"
