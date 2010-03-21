from anygit.backends import database

def deferred_attribute(attr):
    def get(self):
        return getattr(self._backend, attr)

    def set(self, value):
        return setattr(self._backend, attr, value)

    return property(get, set)

def backend_class(klass):
    lookup = {Repository : database.Repository,
              Blob : database.Blob,
              Tree : database.Tree,
              Commit : database.Commit}
    return lookup[klass]

class BackedObject(object):
    def __init__(self, backend):
        self._backend = backend
        self._errors = {}

    def error(self, msg, attr=None):
        error_list = self._errors.setdefault(attr, [])
        error_list.append(msg)

    def clear_errors(self):
        self._errors.clear()

    def validate(self):
        pass

    @classmethod
    def get(cls, **kwargs):
        return backend_class(cls).get(**kwargs)

    @classmethod
    def new(cls, **kwargs):
        backend = backend_class(cls)(**kwargs)
        instance = cls(backend=backend)
        return instance

    @classmethod
    def create(cls, **kwargs):
        instance = cls.new(**kwargs)
        instance.save()
        return instance

    @property
    def type(self):
        return type(self).__name__

    def save(self):
        self.validate()
        if not self._errors:
            self._backend.save()
            return True
        else:
            return False

    def __str__(self):
        return '%s: %s' % (type(self).__name__, self.sha1)

    def __repr__(self):
        return str(self)

class Repository(BackedObject):
    def validate(self):
        super(Repository, self).validate()
        if not self.name:
            self.error('name', 'Must provide a name')
        if not self.url:
            self.error('url', 'Must provide a url')

    name = deferred_attribute('name')
    url = deferred_attribute('url')


class GitObject(BackedObject):
    sha1 = deferred_attribute('sha1')
    repository_names = deferred_attribute('repository_names')
    repositories = deferred_attribute('repositories')

    def validate(self):
        super(GitObject, self).validate()
        if not self.sha1:
            self.error('sha1', 'Must provide a sha1')

    @classmethod
    def lookup_by_sha1(cls, sha1, partial=False):
        return database.GitObject.lookup_by_sha1(sha1, partial=partial)


class Blob(GitObject):
    commit_names = deferred_attribute('commit_names')
    commits = deferred_attribute('commits')

    def add_commit(self, commit):
        return self._backend.add_commit(commit)


class Tree(GitObject):
    commit_names = deferred_attribute('commit_names')
    commits = deferred_attribute('commits')

    def add_commit(self, commit):
        return self._backend.add_commit(commit)


class Commit(GitObject):
    def add_repository(self, repo):
        return self._backend.add_repository(repo)