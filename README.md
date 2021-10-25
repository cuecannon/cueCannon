# Deploying cuecannon to lamdera platform
1) Make new lamdera app
2) Clone cuecannon repository
3) Add ENV params to lamdera (canon url)
4) Copy and past Lamdera git URL in repo to add remote
5) `lamdera deploy`

# Dev tips
When you don't care about data on a migration, use `ModelUnchanged` and `MsgOldValueIgnored`.

# Known problems
If you delete an app in the lamdera dashboard, it seems to delete all apps that share the same commit.
