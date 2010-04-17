import logging
from pylons import config
import sqlalchemy as sa
from sqlalchemy import orm
from sqlalchemy.ext import declarative

from anygit.backends import common
from anygit.data import exceptions

logger = logging.getLogger(__name__)

Session = None
Engine = None
Base = declarative.declarative_base()
Metadata = Base.metadata

max_transaction_window = 10000
curr_transaction_window = 0

def init_model(engine):
    """Call me before using any of the tables or classes in the model."""
    global Session, Engine

    Engine = engine

    sm = orm.sessionmaker(autoflush=True, autocommit=False, bind=engine)
    Session = orm.scoped_session(sm)

def setup():
    """
    Sets up the database session
    """
    engine = sa.engine_from_config(config, 'sqlalchemy.')
    init_model(engine)

def flush():
    logger.debug('Committing...')
    Session.commit()

def canonicalize(obj_or_sha1):
    if isinstance(obj_or_sha1, str):
        obj_or_sha1 = GitObject.get_or_create(id=obj_or_sha1)
    return obj_or_sha1

# Join table for commit -> repositories mapping
commits_repositories = sa.Table(
    'commits_repositories',
    Base.metadata,
    sa.Column('commit_id',
              sa.ForeignKey('commits.id'),
              primary_key=True),
    sa.Column('repository_id',
              sa.ForeignKey('repositories.id'),
              primary_key=True))

# Join table for blob -> commits mapping
blobs_commits = sa.Table(
    'blobs_commits',
    Base.metadata,
    sa.Column('blob_id',
              sa.ForeignKey('blobs.id'),
              primary_key=True),
    sa.Column('commit_id',
              sa.ForeignKey('commits.id'),
              primary_key=True))

# Join table for tree -> commits mapping
trees_commits = sa.Table(
    'trees_commits',
    Base.metadata,
    sa.Column('tree_id',
              sa.ForeignKey('trees.id'),
              primary_key=True),
    sa.Column('commit_id',
              sa.ForeignKey('commits.id'),
              primary_key=True))

# Join table for commit -> parents mapping
commits_parents = sa.Table(
    'commits_parents',
    Base.metadata,
    sa.Column('child_id',
              sa.ForeignKey('commits.id'),
              primary_key=True),
    sa.Column('parent_id',
              sa.ForeignKey('commits.id'),
              primary_key=True))


class SAMixin(object):
    @classmethod
    def get(cls, id):
        """Retrieve an object by primary key"""
        instance = Session.query(cls).get(id)
        if instance:
            return instance
        else:
            raise exceptions.DoesNotExist('%s: %s' % (cls, id))

    @classmethod
    def get_by_attributes(cls, **kwargs):
        results = Session.query(cls)
        for key, value in kwargs.iteritems():
            results = results.filter(getattr(cls, key) == value)
        count = results.count()
        if count == 1:
            return list(results)[0]
        elif count == 0:
            raise exceptions.DoesNotExist('%s: %s' % (cls, kwargs))
        else:
            raise exceptions.NotUnique('%s: %s' % (cls, kwargs))

    @classmethod
    def all(cls):
        return Session.query(cls).all()

    def save(self):
        global curr_transaction_window
        self.validate()
        if not self._errors:
            Session.add(self)
            if curr_transaction_window >= max_transaction_window:
                flush()
                curr_transaction_window = 0
            else:
                curr_transaction_window += 1
            return True
        else:
            return False


class GitObject(Base, SAMixin, common.CommonGitObjectMixin):
    """
    The base class for git objects (such as blobs, commits, etc..).
    Subclasses inherit via join table inheritance.
    """
    __tablename__ = 'git_objects'
    id = sa.Column(sa.types.String(length=40), primary_key=True)
    type = sa.Column(sa.types.String(length=50))
    complete = sa.Column(sa.types.Boolean(default=False))

    __mapper_args__ = {'polymorphic_on': type}

    @classmethod
    def lookup_by_sha1(cls, sha1, partial=False):
        if partial:
            return Session.query(cls).filter(cls.id.startswith(sha1))
        else:
            return Session.query(cls).filter(cls.id == sha1)


class Blob(GitObject, common.CommonBlobMixin):
    """
    Represents a git Blob.  Has an id (the sha1 that identifies this
    object)
    """
    __tablename__ = 'blobs'
    __mapper_args__ = {'polymorphic_identity': 'blob'}
    id = sa.Column(sa.ForeignKey('git_objects.id'),
                   primary_key=True)

    def add_commit(self, commit):
        self.add_commits([commit])

    def add_commits(self, commits):
        commit_set = set(canonicalize(commit) for commit in commits)
        self.commits.union(commit_set)

    @property
    def repositories(self):
        return Session.query(Repository).join('commits', 'blobs').filter(Blob.id==self.id)


class Tree(GitObject, common.CommonTreeMixin):
    """
    Represents a git Tree.  Has an id (the sha1 that identifies this
    object)
    """
    __tablename__ = 'trees'
    __mapper_args__ = {'polymorphic_identity': 'tree'}
    id = sa.Column(sa.ForeignKey('git_objects.id'),
                   primary_key=True)

    def add_commit(self, commit):
        self.add_commits([commit])

    def add_commits(self, commits):
        commit_set = set(canonicalize(commit) for commit in commits)
        self.commits.union(commit_set)

    @property
    def repositories(self):
        return Session.query(Repository).join('commits', 'trees').filter(Tree.id==self.id)


class Tag(GitObject, common.CommonTagMixin):
    """
    Represents a git Tree.  Has an id (the sha1 that identifies this
    object)
    """
    __tablename__ = 'tags'
    __mapper_args__ = {'polymorphic_identity': 'tag'}
    id = sa.Column(sa.ForeignKey('git_objects.id'),
                   primary_key=True)

    commit_id = sa.Column(sa.ForeignKey('commits.id'))


class Commit(GitObject, common.CommonCommitMixin):
    """
    Represents a git Commit.  Has an id (the sha1 that identifies
    this object).  Also contains blobs, trees, and tags.
    """
    __tablename__ = 'commits'
    __mapper_args__ = {'polymorphic_identity': 'commit'}
    id = sa.Column(sa.ForeignKey('git_objects.id'),
                   primary_key=True)

    blobs = orm.relation(Blob,
                         backref=orm.backref('commits',
                                             collection_class=set),
                         collection_class=set,
                         secondary=blobs_commits)

    trees = orm.relation(Tree,
                         backref=orm.backref('commits',
                                             collection_class=set),
                         collection_class=set,
                         secondary=trees_commits)

    tags = orm.relation(Tag,
                        backref='commit',
                        collection_class=set,
                        primaryjoin=(id == Tag.commit_id))

    parents = orm.relation('Commit',
                           backref=orm.backref('children',
                                               collection_class=set),
                           collection_class=set,
                           primaryjoin=(id == commits_parents.c.child_id),
                           secondaryjoin=(id == commits_parents.c.parent_id),
                           secondary=commits_parents)

    def add_repository(self, remote):
        if isinstance(remote, str):
            remote = Repository.get(remote)
        self.repositories.add(remote)

    def add_tree(self, tree):
        if isinstance(tree, str):
            tree = Tree.get_or_create(id=tree)
        self.trees.add(tree)

    def add_parent(self, parent):
        self.add_parents([parent])

    def add_parents(self, parents):
        logger.debug('Adding parents %s' % parents)
        parents = set(canonicalize(p) for p in parents)
        self.parents = self.parents.union(parents)

    def mark_complete(self):
        logger.debug('Markings complete: %s' % self)
        self.complete = True

    @classmethod
    def find_matching(cls, sha1s):
        """Given a list of sha1s, find the matching commit objects"""
        return Session.query(cls).filter(cls.id.in_(sha1s))


class RemoteHead(Base, SAMixin, common.CommonRemoteHeadMixin):
    __tablename__ = 'remote_heads'
    repo_id = sa.Column(sa.ForeignKey('repositories.id'),
                        primary_key=True)
    ref_id = sa.Column(sa.types.String(length=255), primary_key=True)
    commit_id =  sa.Column(sa.ForeignKey('commits.id'))
    commit = orm.relation(Commit,
                          collection_class=set)

class Repository(Base, SAMixin, common.CommonRepositoryMixin):
    """
    A git repository, corresponding to a remote in the-one-repo.git.
    Contains many commits.
    """
    __tablename__ = 'repositories'
    id = sa.Column(sa.types.String(length=40), primary_key=True)
    url = sa.Column(sa.types.String(length=255), unique=True)
    last_index = sa.Column(sa.types.DateTime(), default='NOW')

    commits = orm.relation(Commit,
                           backref=orm.backref('repositories',
                                               collection_class=set),
                           collection_class=set,
                           secondary=commits_repositories)

    remote_heads = orm.relation(RemoteHead,
                                backref='repository',
                                collection_class=set)

    def __str__(self):
        return 'Repository: %s' % self.url
