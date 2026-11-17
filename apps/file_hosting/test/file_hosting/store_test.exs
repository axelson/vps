defmodule FileHosting.StoreTest do
  use FileHosting.StorageCase, async: false

  alias FileHosting.Store

  @moduletag :tmp_dir

  test "publish creates a bundle served through a symlink, with metadata", %{tmp_dir: tmp} do
    tar = tarball(tmp, [{"index.html", "<h1>hi</h1>"}, {"js/app.js", "1"}])

    assert {:ok, meta} = Store.publish("demo", tar)
    assert %{name: "demo", size_bytes: 12, file_count: 2} = meta
    assert meta.created_at == meta.updated_at

    assert {:ok, _} = File.read_link(Store.bundle_dir("demo"))
    assert File.read!(Path.join(Store.bundle_dir("demo"), "js/app.js")) == "1"
    assert File.exists?(Path.join([Store.root(), "meta", "demo.json"]))
    assert Store.get("demo") == {:ok, meta}
    assert Store.list() == [meta]
  end

  test "replacing keeps created_at, swaps content and removes the old version",
       %{tmp_dir: tmp} do
    {:ok, first} = Store.publish("demo", tarball(tmp, [{"index.html", "v1"}, {"old.js", "x"}]))
    old_version = Store.current_version("demo")
    Process.sleep(1100)

    {:ok, second} = Store.publish("demo", tarball(tmp, [{"index.html", "v2"}]))

    assert second.created_at == first.created_at
    assert second.updated_at > first.updated_at
    assert File.read!(Path.join(Store.bundle_dir("demo"), "index.html")) == "v2"
    refute File.exists?(Path.join(Store.bundle_dir("demo"), "old.js"))
    refute File.exists?(Path.join([Store.root(), "versions", old_version]))
  end

  test "a rejected upload leaves the existing bundle untouched", %{tmp_dir: tmp} do
    {:ok, _} = Store.publish("demo", tarball(tmp, [{"index.html", "v1"}]))

    assert {:error, {:invalid, _}} = Store.publish("demo", tarball(tmp, [{"other.html", "x"}]))
    assert File.read!(Path.join(Store.bundle_dir("demo"), "index.html")) == "v1"
    assert File.ls!(Path.join(Store.root(), "staging")) == []
  end

  test "enforces the total quota, not counting the bundle being replaced", %{tmp_dir: tmp} do
    Application.put_env(:file_hosting, :max_total_bytes, 10)

    {:ok, _} = Store.publish("a", tarball(tmp, [{"index.html", "123456"}]))

    assert {:error, :quota_exceeded} =
             Store.publish("b", tarball(tmp, [{"index.html", "123456"}]))

    assert {:ok, _} = Store.publish("a", tarball(tmp, [{"index.html", "1234567890"}]))
  end

  test "delete removes the bundle, its version and its metadata", %{tmp_dir: tmp} do
    {:ok, _} = Store.publish("demo", tarball(tmp, [{"index.html", "v1"}]))

    assert Store.delete("demo") == :ok
    assert Store.get("demo") == {:error, :not_found}
    assert File.ls!(Path.join(Store.root(), "versions")) == []
    assert File.ls!(Path.join(Store.root(), "meta")) == []
    assert Store.delete("demo") == {:error, :not_found}
  end

  test "setup! clears staging and unreferenced versions", %{tmp_dir: tmp} do
    {:ok, _} = Store.publish("demo", tarball(tmp, [{"index.html", "v1"}]))
    File.mkdir_p!(Path.join([Store.root(), "versions", "orphan.1"]))
    File.write!(Path.join([Store.root(), "staging", "partial"]), "x")

    Store.setup!()

    assert File.ls!(Path.join(Store.root(), "versions")) == [Store.current_version("demo")]
    assert File.ls!(Path.join(Store.root(), "staging")) == []
  end
end
