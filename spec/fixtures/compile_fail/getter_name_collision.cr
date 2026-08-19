# Two services whose getter names collide: `App::UserRepo` and
# `AppUserRepo` both map to `app_user_repo`. The container must fail to
# compile, naming both types and the colliding getter.
require "../../../src/quartz"

module App
  @[Quartz::Service]
  class UserRepo
  end
end

@[Quartz::Service]
class AppUserRepo
end
