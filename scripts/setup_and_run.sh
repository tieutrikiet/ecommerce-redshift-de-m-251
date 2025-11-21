#!/bin/bash
# Setup script for data generation project

echo "🔧 Setting up Python environment..."

# Check if faker is already installed
if python3 -c "import faker" 2>/dev/null; then
    echo "✅ Faker is already installed"
else
    echo "📦 Installing faker..."
    pip3 install --break-system-packages faker
fi

# Check if psycopg2 is already installed
if python3 -c "import psycopg2" 2>/dev/null; then
    echo "✅ psycopg2 is already installed"
else
    echo "📦 Installing psycopg2..."
    pip3 install --break-system-packages psycopg2
fi

echo ""
echo "🚀 Running data generator..."
python3 generate_data.py

echo ""
echo "✅ Setup complete!"
