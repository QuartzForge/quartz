module Quartz
  # Carrier for the root module captured at compile time. `Quartz.run`
  # fills `ROOT` from its argument; test harnesses that must not serve
  # traffic declare it by hand instead of calling `run`.
  class Bootstrap; end
end
