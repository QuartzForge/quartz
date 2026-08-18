record UserPayload, id : Int64, name : String do
  include JSON::Serializable
end

record CreateUserPayload, name : String do
  include JSON::Serializable
end

@[Quartz::Service]
class ExampleRepo
  def find(id : Int64) : UserPayload
    UserPayload.new(id, "User #{id}")
  end

  def create(name : String) : UserPayload
    UserPayload.new(99_i64, name)
  end
end

@[Quartz::Controller(prefix: "/users")]
class ExampleController
  def initialize(@repo : ExampleRepo)
  end

  @[Quartz::Get("/:id")]
  def show(id : Int64) : UserPayload
    @repo.find(id)
  end

  @[Quartz::Get("/")]
  def index(page : Int32 = 1) : Array(UserPayload)
    [UserPayload.new(page.to_i64, "page #{page}")]
  end

  @[Quartz::Post("/", status: 201)]
  def create(body : CreateUserPayload) : UserPayload
    @repo.create(body.name)
  end

  @[Quartz::Delete("/:id", status: 204)]
  def destroy(id : Int64) : Nil
  end
end
