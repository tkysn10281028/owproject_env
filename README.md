# owproject_env

## ❌ 制約条件(起動に必要なソフト)

- [x] NodeJS
- [x] 各種フロント用 CLI パッケージ（React,Angular の CLI）
- [x] Java
- [x] Maven クライアントツール
- [x] Docker
- [x] (VSCode などのフロントエンド用 IDE)
- [x] (Eclipse・IntelliJ などのバックエンド用 IDE)
- [x] (Shell スクリプトで実行するため Windows なら WSL)

## ❌ 環境別起動時の注意点

### dev 環境について

- Java は設定として dev プロファイルを使用するため、以下のような引数を起動時に指定すること。

  > --spring.profiles.active=dev

  > -Pdev

## 🌏 環境構築手順

### ★NodeJS

1. 下記の公式サイトにアクセスしてダウンロード
   > https://nodejs.org/ja/download
2. 以下のコマンドを打って、バージョン情報が出れば OK

```
node -v
```

### ★ フロント用 CLI パッケージ(NodeJS インストール後)

#### Angular

- インストール

```
npm install -g @angular/cli
```

- 確認

```
ng version
```

- 起動

```
ng serve
```

#### React

- インストール

```
npm install -g create-react-app
```

- 起動

```
npm start
```

#### Vue

- インストール

```
npm install -g @vue/cli
```

- 確認

```
vue --version
```

- 起動

```
npm run serve
```

### ★Maven

1. Java がインストールされているか確認(出なかったら Java のインストールから)

```
java -version
```

2. 下記の公式サイトにアクセスしてダウンロード
   > https://maven.apache.org/download.cgi

- 「Binary zip archive」または「Binary tar.gz archive」のリンクからダウンロードすること

3. ダウンロードしたファイルを解凍する
4. 環境変数に設定する

- MAVEN_HOME を設定する
- Path に以下を設定する
  > MAVEN_HOME\bin

5. mvn -v と打ってバージョン情報が出れば OK

### ★Docker

1. 公式サイトにアクセスして Docker Desktop をダウンロード
   > https://www.docker.com/ja-jp/

### ★WSL

1. 前提として Windows 10 以上か、11 じゃないと WSL は使えない。以下でバージョンを確認して、1903 以上であれば問題なし。

```
winver
```

2. 管理者権限で PowerShell を開いて、以下を実行する。

```
wsl --install
```

- もし wsl --install が使えない場合は以下を実行

```
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

3. WSL2 を入れる（推奨）

```
wsl --set-default-version 2
```

4. インストール後に以下を実行して欲しいディストリビューションを探す

```
wsl --list --online
```

- Ubuntu をインストールする場合は以下。

```
wsl --install -d Ubuntu
```

5. ドライブを変える方法

```
cd /mnt/c ===> Cドライブに移動
cd /mnt/d ===> Dドライブに移動
```
