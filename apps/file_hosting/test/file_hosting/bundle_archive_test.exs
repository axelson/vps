defmodule FileHosting.BundleArchiveTest do
  use ExUnit.Case, async: true

  import FileHosting.StorageCase, only: [tarball: 2]

  alias FileHosting.BundleArchive

  @moduletag :tmp_dir

  setup %{tmp_dir: tmp} do
    dest = Path.join(tmp, "dest")
    File.mkdir_p!(dest)
    %{dest: dest}
  end

  test "extracts a valid bundle, stripping ./ prefixes", %{tmp_dir: tmp, dest: dest} do
    tar = tarball(tmp, [{"./index.html", "hi"}, {"./css/site.css", "body{}"}])

    assert {:ok, %{size_bytes: 8, file_count: 2}} = BundleArchive.extract(tar, dest, 100_000)
    assert File.read!(Path.join(dest, "css/site.css")) == "body{}"
  end

  test "requires a top-level index.html", %{tmp_dir: tmp, dest: dest} do
    tar = tarball(tmp, [{"sub/index.html", "hi"}])

    assert {:error, {:invalid, "missing top-level index.html"}} =
             BundleArchive.extract(tar, dest, 100_000)
  end

  test "rejects bundles over the size limit", %{tmp_dir: tmp, dest: dest} do
    tar = tarball(tmp, [{"index.html", String.duplicate("a", 101)}])
    assert BundleArchive.extract(tar, dest, 100) == {:error, :too_large}
    assert File.ls!(dest) == []
  end

  test "rejects paths that escape the bundle", %{tmp_dir: tmp, dest: dest} do
    tar = tarball(tmp, [{"index.html", "hi"}, {"../evil.html", "x"}])
    assert {:error, {:invalid, "path escapes" <> _}} = BundleArchive.extract(tar, dest, 100_000)
    refute File.exists?(Path.join(tmp, "evil.html"))
  end

  test "rejects absolute paths", %{tmp_dir: tmp, dest: dest} do
    tar = tarball(tmp, [{"index.html", "hi"}, {"/tmp/evil.html", "x"}])
    assert {:error, {:invalid, "absolute path" <> _}} = BundleArchive.extract(tar, dest, 100_000)
  end

  test "rejects symlinks", %{tmp_dir: tmp, dest: dest} do
    src = Path.join(tmp, "src")
    File.mkdir_p!(src)
    File.write!(Path.join(src, "index.html"), "hi")
    File.ln_s!("/etc/passwd", Path.join(src, "passwd"))
    tar = Path.join(tmp, "links.tar.gz")
    {_, 0} = System.cmd("tar", ["-czf", tar, "-C", src, "."], env: [{"COPYFILE_DISABLE", "1"}])

    assert {:error, {:invalid, "unsupported entry type symlink" <> _}} =
             BundleArchive.extract(tar, dest, 100_000)
  end

  test "rejects data that isn't a gzipped tarball", %{tmp_dir: tmp, dest: dest} do
    path = Path.join(tmp, "junk")
    File.write!(path, "not a tarball")

    assert {:error, {:invalid, "not a valid .tar.gz" <> _}} =
             BundleArchive.extract(path, dest, 100)
  end
end
