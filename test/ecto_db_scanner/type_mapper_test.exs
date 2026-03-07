defmodule EctoDBScanner.TypeMapperTest do
  use ExUnit.Case, async: true

  alias EctoDBScanner.TypeMapper

  describe "map_type/1" do
    test "maps integer types" do
      for type <- ~w(int2 int4 int8 serial bigserial smallserial) do
        assert TypeMapper.map_type(type) == :integer, "expected #{type} to map to :integer"
      end
    end

    test "maps float types" do
      for type <- ~w(float4 float8 numeric) do
        assert TypeMapper.map_type(type) == :float, "expected #{type} to map to :float"
      end
    end

    test "maps boolean" do
      assert TypeMapper.map_type("bool") == :boolean
    end

    test "maps string types" do
      for type <- ~w(varchar text char bpchar citext name) do
        assert TypeMapper.map_type(type) == :string, "expected #{type} to map to :string"
      end
    end

    test "maps date" do
      assert TypeMapper.map_type("date") == :date
    end

    test "maps time types" do
      assert TypeMapper.map_type("time") == :time
      assert TypeMapper.map_type("timetz") == :time
    end

    test "maps naive_datetime" do
      assert TypeMapper.map_type("timestamp") == :naive_datetime
    end

    test "maps datetime" do
      assert TypeMapper.map_type("timestamptz") == :datetime
    end

    test "maps uuid" do
      assert TypeMapper.map_type("uuid") == :uuid
    end

    test "maps json types to map" do
      assert TypeMapper.map_type("json") == :map
      assert TypeMapper.map_type("jsonb") == :map
    end

    test "maps binary" do
      assert TypeMapper.map_type("bytea") == :binary
    end

    test "maps network types to string" do
      for type <- ~w(inet cidr macaddr macaddr8) do
        assert TypeMapper.map_type(type) == :string, "expected #{type} to map to :string"
      end
    end

    test "maps array types" do
      assert TypeMapper.map_type("_text") == {:array, :string}
      assert TypeMapper.map_type("_int4") == {:array, :integer}
      assert TypeMapper.map_type("_bool") == {:array, :boolean}
      assert TypeMapper.map_type("_uuid") == {:array, :uuid}
    end

    test "returns unknown for unrecognized types" do
      assert TypeMapper.map_type("tsvector") == {:unknown, "tsvector"}
      assert TypeMapper.map_type("weird_custom_type") == {:unknown, "weird_custom_type"}
    end
  end
end
